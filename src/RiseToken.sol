// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { IRiseToken } from "./interfaces/IRiseToken.sol";
import { IfERC20 } from "./interfaces/IfERC20.sol";
import { IFuseComptroller } from "./interfaces/IFuseComptroller.sol";
import { IWETH9 } from "./interfaces/IWETH9.sol";
import { IUniswapV2Pair } from "./interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Router02 } from "./interfaces/IUniswapV2Router02.sol";

import { RiseTokenFactory } from "./RiseTokenFactory.sol";
import { UniswapAdapter } from "./adapters/UniswapAdapter.sol";
import { RariFusePriceOracleAdapter } from "./adapters/RariFusePriceOracleAdapter.sol";

/**
 * @title Rise Token (2x Long Token)
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice 2x Long Token powered by Rari Fuse
 */
contract RiseToken is IRiseToken, ERC20, Ownable {

    /// ███ Libraries ████████████████████████████████████████████████████████

    using SafeERC20 for ERC20;
    using SafeERC20 for IWETH9;
    using FixedPointMathLib for uint256;


    /// ███ Storages █████████████████████████████████████████████████████████

    RiseTokenFactory           public immutable factory;
    RariFusePriceOracleAdapter public immutable oracleAdapter;
    IUniswapV2Pair             public immutable pair;
    IUniswapV2Router02         public immutable router;

    ERC20   public immutable collateral;
    ERC20   public immutable debt;
    IfERC20 public immutable fCollateral;
    IfERC20 public immutable fDebt;

    uint256 public totalCollateral;
    uint256 public totalDebt;
    uint256 public maxMint = type(uint256).max;
    uint256 public fees = 0.001 ether; // 0.1%
    uint256 public minLeverageRatio = 1.7 ether;
    uint256 public maxLeverageRatio = 2.3 ether;
    uint256 public step = 0.2 ether;
    uint256 public discount = 0.006 ether; // 0.6%
    bool    public isInitialized;


    /// ███ Modifiers ████████████████████████████████████████████████████████

    modifier whenInitialized() {
        if (!isInitialized) revert Uninitialized();
        _;
    }


    /// ███ Constructor ██████████████████████████████████████████████████████

    constructor(
        string memory _name,
        string memory _symbol,
        RiseTokenFactory _factory,
        IfERC20 _fCollateral,
        IfERC20 _fDebt,
        RariFusePriceOracleAdapter _oracleAdapter,
        IUniswapV2Pair _pair,
        IUniswapV2Router02 _router
    ) ERC20(_name, _symbol) {
        factory = _factory;
        fCollateral = _fCollateral;
        collateral = ERC20(fCollateral.underlying());
        fDebt = _fDebt;
        debt = ERC20(fDebt.underlying());
        oracleAdapter = _oracleAdapter;
        pair = _pair;
        router = _router;

        // Enter the markets
        address[] memory markets = new address[](2);
        markets[0] = address(fCollateral);
        markets[1] = address(fDebt);
        IFuseComptroller troll = IFuseComptroller(fCollateral.comptroller());
        uint256[] memory res = troll.enterMarkets(markets);
        if (res[0] != 0 || res[1] != 0) revert FuseError(res[0]);

        increaseAllowance();
        transferOwnership(factory.owner());
    }


    /// ███ Internal functions ███████████████████████████████████████████████

    function supplyThenBorrow(uint256 _ca, uint256 _ba) internal {
        // Deposit to Rari Fuse
        uint256 fuseResponse;
        fuseResponse = fCollateral.mint(_ca);
        if (fuseResponse != 0) revert FuseError(fuseResponse);
        totalCollateral = fCollateral.balanceOfUnderlying(address(this));

        // Borrow from Rari Fuse
        if (_ba == 0) return;
        fuseResponse = fDebt.borrow(_ba);
        if (fuseResponse != 0) revert FuseError(fuseResponse);
        totalDebt = fDebt.borrowBalanceCurrent(address(this));
    }

    function repayThenRedeem(uint256 _rAmount, uint256 _cAmount) internal {
        // Repay debt to Rari Fuse
        uint256 repayResponse = fDebt.repayBorrow(_rAmount);
        if (repayResponse != 0) revert FuseError(repayResponse);

        // Redeem from Rari Fuse
        uint256 redeemResponse = fCollateral.redeemUnderlying(_cAmount);
        if (redeemResponse != 0) revert FuseError(redeemResponse);

        // Cache the value
        totalCollateral = fCollateral.balanceOfUnderlying(address(this));
        totalDebt = fDebt.borrowBalanceCurrent(address(this));
    }

    function onMint(FlashSwapParams memory _params) internal {
        /// ███ Checks
        if (_params.amountIn == 0) revert AmountInTooLow();
        if (_params.amountOut == 0) revert AmountOutTooLow();

        /// ███ Effects
        supplyThenBorrow(_params.collateralAmount, _params.debtAmount);
        debt.safeTransfer(address(pair), _params.repayAmount);
        if (_params.refundAmount > 0) {
            _params.tokenIn.safeTransfer(
                _params.refundRecipient,
                _params.refundAmount
            );
        }
        if (_params.feeAmount > 0) {
            _params.tokenIn.safeTransfer(
                factory.feeRecipient(),
                _params.feeAmount
            );
        }

        // Mint the shares
        _mint(_params.recipient, _params.amountOut);

        // Emit Swap event
        emit Swap(
            _params.sender,
            _params.recipient,
            address(_params.tokenIn),
            address(_params.tokenOut),
            _params.amountIn,
            _params.amountOut,
            _params.feeAmount,
            price()
        );
    }

    event Debug(string key, uint256 value);

    function onBurn(FlashSwapParams memory _params) internal {
        /// ███ Checks
        if (_params.amountIn == 0) revert AmountInTooLow();
        if (_params.amountOut == 0) revert AmountOutTooLow();

        /// ███ Effects
        emit Debug(
            "tokenOut balance before redeem",
            _params.tokenOut.balanceOf(address(this))
        );
        emit Debug(
            "params.collateralAmount",
            _params.collateralAmount
        );
        repayThenRedeem(_params.debtAmount, _params.collateralAmount);
        collateral.safeTransfer(address(pair), _params.repayAmount);
        if (_params.feeAmount > 0) {
            _params.tokenOut.safeTransfer(
                factory.feeRecipient(),
                _params.feeAmount
            );
        }

        // Burn the shares and send the tokenOut
        emit Debug("conttract balance", balanceOf(address(this)));
        emit Debug("params amountIn", _params.amountIn);
        _burn(address(this), _params.amountIn);
        emit Debug("params amountOut", _params.amountOut);
        emit Debug(
            "tokenOut balance after redeem",
            _params.tokenOut.balanceOf(address(this))
        );
        _params.tokenOut.safeTransfer(_params.recipient, _params.amountOut);

        // Emit Swap event
        emit Swap(
            _params.sender,
            _params.recipient,
            address(_params.tokenIn),
            address(_params.tokenOut),
            _params.amountIn,
            _params.amountOut,
            _params.feeAmount,
            price()
        );
    }


    /// ███ Owner actions ████████████████████████████████████████████████████

    /// @inheritdoc IRiseToken
    function setParams(
        uint256 _minLeverageRatio,
        uint256 _maxLeverageRatio,
        uint256 _step,
        uint256 _discount,
        uint256 _newMaxMint
    ) external onlyOwner {
        // Checks
        if (_minLeverageRatio < 1 ether || _maxLeverageRatio > 3 ether) {
            revert InvalidLeverageRatio();
        }
        // plus or minus 0.5x leverage in one rebalance is too much
        if (_step > 0.5 ether || _step < 0.1 ether) revert InvalidRebalancingStep();
        // 5% discount too much; 0.1% discount too low
        if (_discount > 0.05 ether || _discount < 0.001 ether)  {
            revert InvalidDiscount();
        }

        // Effects
        minLeverageRatio = _minLeverageRatio;
        maxLeverageRatio = _maxLeverageRatio;
        step = _step;
        discount = _discount;
        maxMint = _newMaxMint;

        emit ParamsUpdated(minLeverageRatio, maxLeverageRatio, step, discount, maxMint);
    }

    /// @inheritdoc IRiseToken
    function initialize(
        uint256 _ca,
        uint256 _da,
        uint256 _shares
    ) external onlyOwner {
        if (isInitialized) revert Uninitialized();
        isInitialized = true;

        address[] memory path = new address[](2);
        path[0] = address(debt);
        path[1] = address(collateral);
        uint256 repayAmount = router.getAmountsIn(_ca, path)[0];
        if (repayAmount < _da) revert AmountInTooLow();

        uint256 amountInUsed = repayAmount - _da;
        uint256 amountIn = debt.balanceOf(address(this));
        if(amountIn < amountInUsed) revert AmountInTooLow();
        uint256 refundAmount = amountIn - amountInUsed;

        // Borrow collateral from pair
        address c = address(collateral);
        uint256 amount0Out = c == pair.token0() ? _ca : 0;
        uint256 amount1Out = c == pair.token1() ? _ca : 0;

        // Do the instant leverage
        FlashSwapParams memory params = FlashSwapParams({
            flashSwapType: FlashSwapType.Mint,
            sender: msg.sender,
            recipient: msg.sender,
            refundRecipient: msg.sender,
            tokenIn: debt,
            tokenOut: ERC20(address(this)),
            amountIn: amountInUsed,
            amountOut: _shares,
            feeAmount: 0,
            refundAmount: refundAmount,
            borrowAmount: _ca,
            repayAmount: repayAmount,
            collateralAmount: _ca,
            debtAmount: _da
        });
        bytes memory data = abi.encode(params);
        pair.swap(amount0Out, amount1Out, address(this), data);
    }


    /// ███ External functions ███████████████████████████████████████████████

    function pancakeCall(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes memory _data
    ) external {
        _callback(_sender, _amount0, _amount1, _data);
    }

    function uniswapV2Call(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes memory _data
    ) external {
        _callback(_sender, _amount0, _amount1, _data);
    }

    function _callback(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes memory _data
    ) internal {
        /// ███ Checks
        if (msg.sender != address(pair)) revert Unauthorized();
        if (_sender != address(this)) revert Unauthorized();
        // Check collateral amount received from flash swap
        uint256 r = _amount0 == 0 ? _amount1 : _amount0;

        // Continue execution based on the type
        FlashSwapParams memory params = abi.decode(_data, (FlashSwapParams));
        if (r != params.borrowAmount) revert InvalidFlashSwapAmount();

        if (params.flashSwapType == FlashSwapType.Mint) {
            onMint(params);
            return;
        } else if (params.flashSwapType == FlashSwapType.Burn) {
            onBurn(params);
            return;
        } else revert InvalidFlashSwapType();
    }

    function increaseAllowance() public {
        uint256 max = type(uint256).max;
        collateral.safeIncreaseAllowance(address(fCollateral), max);
        debt.safeIncreaseAllowance(address(fDebt), max);
    }


    /// ███ Read-only functions ██████████████████████████████████████████████

    /// @inheritdoc IRiseToken
    function sharesToUnderlying(
        uint256 _amount
    ) public view whenInitialized returns (uint256 _ca, uint256 _da) {
        _ca = _amount.mulDivDown(totalCollateral, totalSupply());
        _da = _amount.mulDivDown(totalDebt, totalSupply());
    }

    /// @inheritdoc IRiseToken
    function collateralPerShare() public view whenInitialized returns (uint256 _cps) {
        (_cps, ) = sharesToUnderlying(1 ether);
    }

    /// @inheritdoc IRiseToken
    function debtPerShare() public view whenInitialized returns (uint256 _dps) {
        ( ,_dps) = sharesToUnderlying(1 ether);
    }

    /// @inheritdoc IRiseToken
    function value(
        uint256 _shares
    ) public view whenInitialized returns (uint256 _value) {
        if (_shares == 0) return 0;

        // Get the collateral & debt amount
        (uint256 ca, uint256 da) = sharesToUnderlying(_shares);

        // Get the collateral value in ETH
        uint256 cv = oracleAdapter.totalValue(
            address(collateral),
            address(0),
            ca
        );
        uint256 dv = oracleAdapter.totalValue(
            address(debt),
            address(0),
            da
        );

        // Get total value in terms of debt token
        _value = cv - dv;
    }

    /// @inheritdoc IRiseToken
    function price() public view whenInitialized returns (uint256 _price) {
        _price = value(1 ether);
    }

    /// @inheritdoc IRiseToken
    function leverageRatio() public whenInitialized view returns (uint256 _lr) {
        uint256 cv = oracleAdapter.totalValue(
            address(collateral),
            address(debt),
            totalCollateral
        );
        _lr = cv.divWadUp(cv - totalDebt);
    }


    /// ███ User actions █████████████████████████████████████████████████████

    /// @inheritdoc IRiseToken
    function mintd(
        uint256 _shares,
        address _recipient,
        address _refundRecipient
    ) external whenInitialized {
        /// ███ Checks
        if (_shares == 0) revert AmountOutTooLow();
        if (_shares > maxMint) revert AmountOutTooHigh();

        FlashSwapParams memory params;

        {
            (uint256 ca, uint256 da) = sharesToUnderlying(_shares);
            address[] memory path = new address[](2);
            path[0] = address(debt);
            path[1] = address(collateral);
            uint256 repayAmount = router.getAmountsIn(ca, path)[0];
            uint256 borrowAmount = ca;

            if (repayAmount < da) revert AmountInTooLow();
            uint256 amountInUsed = repayAmount - da;
            uint256 feeAmount = fees.mulWadDown(amountInUsed);
            uint256 amountIn = debt.balanceOf(address(this));

            if (amountIn < amountInUsed + feeAmount) revert AmountInTooLow();
            uint256 refundAmount = amountIn - (amountInUsed + feeAmount);

            params = FlashSwapParams({
                flashSwapType: FlashSwapType.Mint,
                sender: msg.sender,
                recipient: _recipient,
                refundRecipient: _refundRecipient,
                tokenIn: debt,
                tokenOut: ERC20(address(this)),
                amountIn: amountInUsed,
                amountOut: _shares,
                feeAmount: feeAmount,
                refundAmount: refundAmount,
                borrowAmount: borrowAmount,
                repayAmount: repayAmount,
                collateralAmount: ca,
                debtAmount: da
            });
        }

        // Do the instant leverage
        address c = address(collateral);
        uint256 amount0Out = c == pair.token0() ? params.borrowAmount : 0;
        uint256 amount1Out = c == pair.token1() ? params.borrowAmount : 0;
        bytes memory data = abi.encode(params);
        pair.swap(amount0Out, amount1Out, address(this), data);
    }

    /// @inheritdoc IRiseToken
    function mintc(
        uint256 _shares,
        address _recipient,
        address _refundRecipient
    ) external whenInitialized {
        /// ███ Checks
        if (_shares == 0) revert AmountOutTooLow();
        if (_shares > maxMint) revert AmountOutTooHigh();

        FlashSwapParams memory params;

        {
            (uint256 ca, uint256 da) = sharesToUnderlying(_shares);
            address[] memory path = new address[](2);
            path[0] = address(debt);
            path[1] = address(collateral);
            uint256 repayAmount = da;
            uint256 borrowAmount = router.getAmountsOut(repayAmount, path)[1];

            if (ca < borrowAmount) revert AmountInTooLow();
            uint256 amountInUsed = ca - borrowAmount;
            uint256 feeAmount = fees.mulWadDown(amountInUsed);
            uint256 amountIn = collateral.balanceOf(address(this));

            if (amountIn < amountInUsed + feeAmount) revert AmountInTooLow();
            uint256 refundAmount = amountIn - (amountInUsed + feeAmount);

            params = FlashSwapParams({
                flashSwapType: FlashSwapType.Mint,
                sender: msg.sender,
                recipient: _recipient,
                refundRecipient: _refundRecipient,
                tokenIn: collateral,
                tokenOut: ERC20(address(this)),
                amountIn: amountInUsed,
                amountOut: _shares,
                feeAmount: feeAmount,
                refundAmount: refundAmount,
                borrowAmount: borrowAmount,
                repayAmount: repayAmount,
                collateralAmount: ca,
                debtAmount: da
            });
        }

        // Do the instant leverage
        address c = address(collateral);
        uint256 amount0Out = c == pair.token0() ? params.borrowAmount : 0;
        uint256 amount1Out = c == pair.token1() ? params.borrowAmount : 0;
        bytes memory data = abi.encode(params);
        pair.swap(amount0Out, amount1Out, address(this), data);
    }

    /// @inheritdoc IRiseToken
    function burnd(
        address _recipient,
        uint256 _minAmountOut
    ) external whenInitialized {
        uint256 burnAmount = balanceOf(address(this));
        if (burnAmount == 0) revert AmountInTooLow();

        FlashSwapParams memory params;

        {
            (uint256 ca, uint256 da) = sharesToUnderlying(burnAmount);
            address[] memory path = new address[](2);
            path[0] = address(collateral);
            path[1] = address(debt);
            uint256 repayAmount = ca;
            uint256 borrowAmount = router.getAmountsOut(repayAmount, path)[1];

            if (borrowAmount < da) revert AmountOutTooLow();
            uint256 amountOut = borrowAmount - da;
            uint256 feeAmount = fees.mulWadDown(amountOut);
            amountOut -= feeAmount;
            if (amountOut < _minAmountOut) revert AmountOutTooLow();

            params = FlashSwapParams({
                flashSwapType: FlashSwapType.Burn,
                sender: msg.sender,
                recipient: _recipient,
                refundRecipient: address(0),
                tokenIn: ERC20(address(this)),
                tokenOut: debt,
                amountIn: burnAmount,
                amountOut: amountOut,
                feeAmount: feeAmount,
                refundAmount: 0,
                borrowAmount: borrowAmount,
                repayAmount: repayAmount,
                collateralAmount: ca,
                debtAmount: da
            });
        }

        // Do the instant close position
        address d = address(debt);
        emit Debug("burnAmount", burnAmount);
        emit Debug("params amountIn", params.amountIn);
        uint256 amount0Out = d == pair.token0() ? params.borrowAmount : 0;
        uint256 amount1Out = d == pair.token1() ? params.borrowAmount : 0;
        bytes memory data = abi.encode(params);
        pair.swap(amount0Out, amount1Out, address(this), data);
    }

    /// @inheritdoc IRiseToken
    function burnc(
        address _recipient,
        uint256 _minAmountOut
    ) external whenInitialized {
        uint256 burnAmount = balanceOf(address(this));
        if (burnAmount == 0) revert AmountInTooLow();

        FlashSwapParams memory params;

        {
            (uint256 ca, uint256 da) = sharesToUnderlying(burnAmount);
            address[] memory path = new address[](2);
            path[0] = address(collateral);
            path[1] = address(debt);
            uint256 repayAmount = router.getAmountsIn(da, path)[0];
            uint256 borrowAmount = da;

            if (ca < repayAmount) revert AmountOutTooLow();
            uint256 amountOut = ca - repayAmount;
            uint256 feeAmount = fees.mulWadDown(amountOut);
            amountOut -= feeAmount;
            if (amountOut < _minAmountOut) revert AmountOutTooLow();

            params = FlashSwapParams({
                flashSwapType: FlashSwapType.Burn,
                sender: msg.sender,
                recipient: _recipient,
                refundRecipient: address(0),
                tokenIn: ERC20(address(this)),
                tokenOut: collateral,
                amountIn: burnAmount,
                amountOut: amountOut,
                feeAmount: feeAmount,
                refundAmount: 0,
                borrowAmount: borrowAmount,
                repayAmount: repayAmount,
                collateralAmount: ca,
                debtAmount: da
            });
        }

        // Do the instant close position
        address d = address(debt);
        uint256 amount0Out = d == pair.token0() ? params.borrowAmount : 0;
        uint256 amount1Out = d == pair.token1() ? params.borrowAmount : 0;
        bytes memory data = abi.encode(params);
        pair.swap(amount0Out, amount1Out, address(this), data);
    }


    /// ███ Market makers ████████████████████████████████████████████████████

    /// @inheritdoc IRiseToken
    function push(
        uint256 _amountIn
    ) external whenInitialized returns (uint256 _amountOut) {
        /// ███ Checks
        if (leverageRatio() > minLeverageRatio) revert Balance();
        if (_amountIn == 0) return 0;

        // Prev states
        uint256 prevLeverageRatio = leverageRatio();
        uint256 prevTotalCollateral = totalCollateral;
        uint256 prevTotalDebt = totalDebt;
        uint256 prevPrice = price();

        // Discount the price
        uint256 amountInValue = oracleAdapter.totalValue(
            address(collateral),
            address(debt),
            _amountIn
        );
        _amountOut = amountInValue + discount.mulWadDown(amountInValue);

        // Cap the swap amount
        // This is our buying power; can't buy collateral more than this
        uint256 maxBorrowAmount = step.mulWadDown(value(totalSupply()));
        if (_amountOut > maxBorrowAmount) {
            revert InvalidSwapAmount(maxBorrowAmount, _amountOut);
        }

        /// ███ Effects

        // Supply then borrow
        collateral.safeTransferFrom(msg.sender, address(this), _amountIn);
        supplyThenBorrow(_amountIn, _amountOut);
        debt.safeTransfer(msg.sender, _amountOut);

        // Emit event
        emit Rebalanced(
            msg.sender,
            prevLeverageRatio,
            leverageRatio(),
            prevTotalCollateral,
            totalCollateral,
            prevTotalDebt,
            totalDebt,
            prevPrice,
            price()
        );
    }

    /// @inheritdoc IRiseToken
    function pull(
        uint256 _amountOut
    ) external whenInitialized returns (uint256 _amountIn) {
        /// ███ Checks
        if (leverageRatio() < maxLeverageRatio) revert Balance();
        if (_amountOut == 0) return 0;

        // Prev states
        uint256 prevLeverageRatio = leverageRatio();
        uint256 prevTotalCollateral = totalCollateral;
        uint256 prevTotalDebt = totalDebt;
        uint256 prevPrice = price();

        // Discount the price
        uint256 amountOutValue = oracleAdapter.totalValue(
            address(collateral),
            address(debt),
            _amountOut
        );
        _amountIn = amountOutValue - discount.mulWadDown(amountOutValue);

        // Cap the swap amount
        // This is our selling power; can't sell collateral more than this
        uint256 maxRepayAmount = step.mulWadDown(value(totalSupply()));
        if (_amountIn > maxRepayAmount) {
            revert InvalidSwapAmount(maxRepayAmount, _amountIn);
        }

        /// ███ Effects

        // Repay then redeem
        debt.safeTransferFrom(msg.sender, address(this), _amountIn);
        repayThenRedeem(_amountIn, _amountOut);
        collateral.safeTransfer(msg.sender, _amountOut);

        // Emit event
        emit Rebalanced(
            msg.sender,
            prevLeverageRatio,
            leverageRatio(),
            prevTotalCollateral,
            totalCollateral,
            prevTotalDebt,
            totalDebt,
            prevPrice,
            price()
        );
    }

    /// @notice Receives ETH when interacting with Uniswap or Fuse
    receive() external payable {}
}
