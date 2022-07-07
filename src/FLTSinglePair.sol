// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { IFLT } from "./interfaces/IFLT.sol";
import { IUniswapV2Pair } from "./interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Router02 } from "./interfaces/IUniswapV2Router02.sol";
import { IfERC20 } from "./interfaces/IfERC20.sol";
import { IFuseComptroller } from "./interfaces/IFuseComptroller.sol";

import { FLTFactory } from "./FLTFactory.sol";
import { RariFusePriceOracleAdapter } from "./adapters/RariFusePriceOracleAdapter.sol";

/**
 * @title Fuse Leveraged Token via Single Pair
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @dev This is optimized version of RiseToken for single pair liquidity
 */
contract FLTSinglePair is IFLT, ERC20, Owned {

    /// ███ Libraries ████████████████████████████████████████████████████████

    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;


    /// ███ Storages █████████████████████████████████████████████████████████

    FLTFactory                 public factory;
    RariFusePriceOracleAdapter public oracleAdapter;
    IUniswapV2Pair             public pair;
    IUniswapV2Router02         public router;

    ERC20   public collateral;
    ERC20   public debt;
    IfERC20 public fCollateral;
    IfERC20 public fDebt;

    uint256 public totalCollateral;
    uint256 public totalDebt;
    uint256 public maxSupply;
    uint256 public fees;
    uint256 public targetLeverageRatio;
    uint256 public minLeverageRatio;
    uint256 public maxLeverageRatio;
    uint256 public maxDrift;
    uint256 public maxIncentive;
    bool    public isInitialized;

    // Deployment status
    bool    internal isDeployed;

    constructor() ERC20("SP", "FLT", 18) Owned(msg.sender) {}

    /// ███ Modifiers ████████████████████████████████████████████████████████

    modifier whenInitialized() {
        if (!isInitialized) revert Uninitialized();
        _;
    }


    /// ███ Deployment ███████████████████████████████████████████████████████

    /// @inheritdoc IFLT
    function deploy(
        address _factory,
        string memory _name,
        string memory _symbol,
        bytes  memory _data
    ) external {
        if (isDeployed) revert Deployed();
        isDeployed = true;

        // Set token metadata
        name = _name;
        symbol = _symbol;
        owner = Owned(_factory).owner();

        // Parse data
        (
            address fc,
            address fd,
            address o,
            address p,
            address r
        ) = abi.decode(_data, (address,address,address,address,address));

        // Setup storages
        factory = FLTFactory(_factory);
        fCollateral = IfERC20(fc);
        collateral = ERC20(fCollateral.underlying());
        fDebt = IfERC20(fd);
        debt = ERC20(fDebt.underlying());
        oracleAdapter = RariFusePriceOracleAdapter(o);
        pair = IUniswapV2Pair(p);
        router = IUniswapV2Router02(r);

        maxSupply = 1_000_000 ether; // 1M by default
        fees = 0.001 ether; // 0.1%
        minLeverageRatio = 1.6 ether;
        maxLeverageRatio = 2.5 ether;
        maxDrift = 0.4 ether;
        maxIncentive = 0.2 ether; // 20%
        targetLeverageRatio = 2 ether;

        // Enter the markets
        address[] memory markets = new address[](2);
        markets[0] = address(fCollateral);
        markets[1] = address(fDebt);
        IFuseComptroller troll = IFuseComptroller(fCollateral.comptroller());
        uint256[] memory res = troll.enterMarkets(markets);
        if (res[0] != 0 || res[1] != 0) revert FuseError(res[0]);

        increaseAllowance();
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

    function onBurn(FlashSwapParams memory _params) internal {
        /// ███ Checks
        if (_params.amountIn == 0) revert AmountInTooLow();
        if (_params.amountOut == 0) revert AmountOutTooLow();

        /// ███ Effects
        repayThenRedeem(_params.debtAmount, _params.collateralAmount);
        collateral.safeTransfer(address(pair), _params.repayAmount);
        if (_params.feeAmount > 0) {
            _params.tokenOut.safeTransfer(
                factory.feeRecipient(),
                _params.feeAmount
            );
        }

        // Burn the shares and send the tokenOut
        _burn(address(this), _params.amountIn);
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

    /// @inheritdoc IFLT
    function setParams(
        uint256 _minLeverageRatio,
        uint256 _maxLeverageRatio,
        uint256 _maxDrift,
        uint256 _maxIncentive,
        uint256 _maxSupply
    ) external onlyOwner {
        // Checks
        if (_minLeverageRatio > _maxLeverageRatio) {
            revert InvalidLeverageRatio();
        }
        // Drift 0.8x from min leverage ratio or max leverage ratio is too high
        if (_maxDrift > 0.8 ether || _maxDrift < 0.3 ether) {
            revert InvalidMaxDrift();
        }
        // max 20% disount min 5% incentives
        if (_maxIncentive > 0.2 ether || _maxIncentive < 0.05 ether)  {
            revert InvalidMaxIncentive();
        }

        // Effects
        minLeverageRatio = _minLeverageRatio;
        maxLeverageRatio = _maxLeverageRatio;
        maxDrift = _maxDrift;
        maxIncentive = _maxIncentive;
        maxSupply = _maxSupply;

        emit ParamsUpdated(
            minLeverageRatio,
            maxLeverageRatio,
            maxDrift,
            maxIncentive,
            maxSupply
        );
    }

    /// @inheritdoc IFLT
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

        FlashSwapParams memory params = abi.decode(_data, (FlashSwapParams));
        // Make sure borrowed amount from flash swap is correct
        uint256 r = _amount0 == 0 ? _amount1 : _amount0;
        if (r != params.borrowAmount) revert InvalidFlashSwapAmount();

        if (params.flashSwapType == FlashSwapType.Mint) {
            onMint(params);
            return;
        } else if (params.flashSwapType == FlashSwapType.Burn) {
            onBurn(params);
            return;
        } else revert InvalidFlashSwapType();
    }

    /// @inheritdoc IFLT
    function increaseAllowance() public {
        uint256 max = type(uint256).max;
        collateral.safeApprove(address(fCollateral), max);
        debt.safeApprove(address(fDebt), max);
    }


    /// ███ Read-only functions ██████████████████████████████████████████████

    /// @inheritdoc IFLT
    function sharesToUnderlying(
        uint256 _amount
    ) public view whenInitialized returns (uint256 _ca, uint256 _da) {
        _ca = _amount.mulDivDown(totalCollateral, totalSupply);
        _da = _amount.mulDivDown(totalDebt, totalSupply);
    }

    /// @inheritdoc IFLT
    function collateralPerShare() public view whenInitialized returns (uint256 _cps) {
        (_cps, ) = sharesToUnderlying(1 ether);
    }

    /// @inheritdoc IFLT
    function debtPerShare() public view whenInitialized returns (uint256 _dps) {
        ( ,_dps) = sharesToUnderlying(1 ether);
    }

    /// @inheritdoc IFLT
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

    /// @inheritdoc IFLT
    function price() public view whenInitialized returns (uint256 _price) {
        _price = value(1 ether);
    }

    /// @inheritdoc IFLT
    function leverageRatio() public whenInitialized view returns (uint256 _lr) {
        uint256 cv = oracleAdapter.totalValue(
            address(collateral),
            address(debt),
            totalCollateral
        );
        _lr = cv.divWadUp(cv - totalDebt);
    }


    /// ███ User actions █████████████████████████████████████████████████████

    /// @inheritdoc IFLT
    function mintd(
        uint256 _shares,
        address _recipient,
        address _refundRecipient
    ) external whenInitialized {
        /// ███ Checks
        if (_shares == 0) revert AmountOutTooLow();
        if (_shares + totalSupply > maxSupply) revert AmountOutTooHigh();

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

    /// @inheritdoc IFLT
    function mintc(
        uint256 _shares,
        address _recipient,
        address _refundRecipient
    ) external whenInitialized {
        /// ███ Checks
        if (_shares == 0) revert AmountOutTooLow();
        if (_shares + totalSupply > maxSupply) revert AmountOutTooHigh();

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

    /// @inheritdoc IFLT
    function burnd(
        address _recipient,
        uint256 _minAmountOut
    ) external whenInitialized {
        uint256 burnAmount = balanceOf[address(this)];
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
        uint256 amount0Out = d == pair.token0() ? params.borrowAmount : 0;
        uint256 amount1Out = d == pair.token1() ? params.borrowAmount : 0;
        bytes memory data = abi.encode(params);
        pair.swap(amount0Out, amount1Out, address(this), data);
    }

    /// @inheritdoc IFLT
    function burnc(
        address _recipient,
        uint256 _minAmountOut
    ) external whenInitialized {
        uint256 burnAmount = balanceOf[address(this)];
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

    /// @inheritdoc IFLT
    function pushc()
        external
        whenInitialized
        returns (uint256 _amountOut, uint256 _incentiveAmount)
    {
        /// ███ Checks
        uint256 lr = leverageRatio();
        uint256 amountIn = collateral.balanceOf(address(this));

        if (lr > minLeverageRatio) revert Balance();
        if (amountIn == 0) revert AmountInTooLow();

        uint256 amountOut = oracleAdapter.totalValue(
            address(collateral),
            address(debt),
            amountIn
        );
        uint256 incentive = (minLeverageRatio - lr).mulDivDown(
            maxIncentive,
            maxDrift
        );
        _incentiveAmount = incentive.mulWadDown(amountOut);
        _amountOut = amountOut + _incentiveAmount;

        // Leverage up to 50% from current leverage to target leverage ratio
        // e.g. lr = 1.75 target is 2.0 then the step is (2-1.75)/2 = 0.125
        uint256 step = (targetLeverageRatio - lr).mulWadDown(0.5 ether);
        uint256 maxAmountOutInETH = step.mulWadDown(value(totalSupply));
        uint256 maxAmountOut = oracleAdapter.totalValue(
            address(0),
            address(debt),
            maxAmountOutInETH
        );
        if (_amountOut > maxAmountOut) revert AmountOutTooHigh();
        if (_amountOut == 0) revert AmountOutTooLow();

        // Prev states
        uint256 prevLeverageRatio = lr;
        uint256 prevTotalCollateral = totalCollateral;
        uint256 prevTotalDebt = totalDebt;
        uint256 prevPrice = price();

        /// ███ Effects
        // Supply then borrow
        supplyThenBorrow(amountIn, _amountOut);
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

    /// @inheritdoc IFLT
    function pushd() external whenInitialized {
        /// ███ Checks
        uint256 lr = leverageRatio();
        if (lr < maxLeverageRatio) revert Balance();
        uint256 amountIn = debt.balanceOf(address(this));
        if (amountIn == 0) revert AmountInTooLow();

        uint256 step = (lr - targetLeverageRatio).mulWadDown(0.5 ether);
        uint256 amountOutInETH = step.mulWadDown(value(totalSupply));
        uint256 amountOut = oracleAdapter.totalValue(
            address(0),
            address(collateral),
            amountOutInETH
        );
        uint256 expectedAmountIn = oracleAdapter.totalValue(
            address(0),
            address(debt),
            amountOutInETH
        );
        // temp
        uint256 discount = 0.01 ether;
        uint256 amountInDiscount = discount.mulWadDown(expectedAmountIn);
        uint256 minAmountIn = expectedAmountIn - amountInDiscount;

        // Make sure debt token is sent to this contract
        if (amountIn < minAmountIn) revert AmountInTooLow();
        uint256 refundAmountIn = amountIn - minAmountIn;

        // Prev states
        uint256 prevLeverageRatio = lr;
        uint256 prevTotalCollateral = totalCollateral;
        uint256 prevTotalDebt = totalDebt;
        uint256 prevPrice = price();

        /// ███ Effects
        // Repay then redeem
        repayThenRedeem(minAmountIn, amountOut);
        collateral.safeTransfer(msg.sender, amountOut);
        if (refundAmountIn > 0) {
            debt.safeTransfer(msg.sender, refundAmountIn);
        }

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
}
