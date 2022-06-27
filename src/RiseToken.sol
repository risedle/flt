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
    uint256 public maxBuy = type(uint256).max;
    uint256 public fees = 0.001 ether;
    uint256 public minLeverageRatio = 1.7 ether;
    uint256 public maxLeverageRatio = 2.3 ether;
    uint256 public step = 0.2 ether;
    uint256 public discount = 0.006 ether; // 0.6%
    bool    public isInitialized;


    /// ███ Modifiers ████████████████████████████████████████████████████████

    modifier whenInitialized() {
        if (!isInitialized) revert TokenNotInitialized();
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

    function onInitialize(
        address _sender,
        uint256 _lr,
        uint256 _ca,
        uint256 _da,
        uint256 _shares
    ) internal {
        // Enter the markets
        address[] memory markets = new address[](2);
        markets[0] = address(fCollateral);
        markets[1] = address(fDebt);
        IFuseComptroller troll = IFuseComptroller(fCollateral.comptroller());
        uint256[] memory res = troll.enterMarkets(markets);
        if (res[0] != 0 || res[1] != 0) revert FuseError(res[0]);

        uint256 amountIn = debt.balanceOf(address(this));
        onMint(_sender, _sender, _shares, _ca, _da, address(debt), amountIn);
        isInitialized = true;
        emit Initialized(_sender, _lr, totalCollateral, totalDebt, totalSupply());
    }

    function onMint(
        address _sender,
        address _recipient,
        uint256 _shares,
        uint256 _ca,
        uint256 _da,
        address _tokenIn,
        uint256 _amountIn
    ) internal {
        /// ███ Effects
        supplyThenBorrow(_ca, _da);

        address[] memory path = new address[](2);
        path[0] = address(debt);
        path[1] = address(collateral);
        uint256 requiredAmount = router.getAmountsIn(_ca, path)[0];
        uint256 totalAmount = debt.balanceOf(address(this));
        if(totalAmount < requiredAmount) {
            revert InvalidBalance();
        }
        debt.safeTransfer(address(pair), requiredAmount);

        // Refund if any
        if (totalAmount > requiredAmount) {
            debt.safeTransfer(_sender, totalAmount - requiredAmount);
        }

        // Mint the shares
        _mint(_recipient, _shares);

        // Emit
        emit RiseTokenMinted(_recipient, _shares, _tokenIn, _amountIn);
    }

    function onBurn(
        uint256 _wethRepayAmount,
        uint256 _debtAmount,
        bytes memory _data
    ) internal {
    }


    /// ███ Owner actions ████████████████████████████████████████████████████

    /// @inheritdoc IRiseToken
    function setParams(
        uint256 _minLeverageRatio,
        uint256 _maxLeverageRatio,
        uint256 _step,
        uint256 _discount,
        uint256 _newMaxBuy
    ) external onlyOwner {
        // Checks
        if (_minLeverageRatio < 1 ether || _maxLeverageRatio > 3 ether) {
            revert InvalidLeverageRatio();
        }
        // plus or minus 0.5x leverage in once rebalance is too much
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
        maxBuy = _newMaxBuy;

        emit ParamsUpdated(minLeverageRatio, maxLeverageRatio, step, discount, maxBuy);
    }

    /// @inheritdoc IRiseToken
    function initialize(
        uint256 _lr,
        uint256 _ca,
        uint256 _da,
        uint256 _shares
    ) external onlyOwner {
        if (isInitialized) revert TokenInitialized();

        // Borrow collateral from pair for instant leverage
        address c = address(collateral);
        uint256 amount0Out = c == pair.token0() ? _ca : 0;
        uint256 amount1Out = c == pair.token1() ? _ca : 0;
        bytes memory data = abi.encode(
            FlashSwapType.Initialize,
            abi.encode(msg.sender,_lr,_ca,_da,_shares)
        );
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
        (
            FlashSwapType flashSwapType,
            bytes memory data
        ) = abi.decode(_data, (FlashSwapType,bytes));

        if (flashSwapType == FlashSwapType.Initialize) {
            (
                address sender,
                uint256 lr,
                uint256 ca,
                uint256 da,
                uint256 shares
            ) = abi.decode(
                data,
                (address,uint256,uint256,uint256,uint256)
            );
            if (r != ca) revert InvalidFlashSwapAmount(ca, r);
            onInitialize(sender, lr, ca, da, shares);
            return;
        } else if (flashSwapType == FlashSwapType.Mint) {
            (
                address sender,
                address recipient,
                uint256 shares,
                uint256 ca,
                uint256 da,
                address tokenIn,
                uint256 amountIn
            ) = abi.decode(
                data,
                (address,address,uint256,uint256,uint256,address,uint256)
            );
            onMint(sender,recipient, shares, ca, da, tokenIn, amountIn);
            return;
        } else if (flashSwapType == FlashSwapType.Burn) {
            // onBurn(data);
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
    function mint(
        uint256 _shares,
        address _recipient,
        address _tokenIn,
        address _amountIn
    ) external whenInitialized {
        /// ███ Checks
        if (_shares > maxBuy) revert SwapAmountTooLarge();
        (uint256 ca, uint256 da) = sharesToUnderlying(_shares);

        // Borrow collateral from pair
        address c = address(collateral);
        uint256 amount0Out = c == pair.token0() ? ca : 0;
        uint256 amount1Out = c == pair.token1() ? ca : 0;

        // Do the instant leverage
        bytes memory data = abi.encode(
            msg.sender,
            _recipient,
            _shares,
            ca,
            da,
            _tokenIn,
            _amountIn
        );
        pair.swap(amount0Out, amount1Out, address(this), data);
    }

    /// @inheritdoc IRiseToken
    function burn() external whenInitialized {
    }


    /// ███ Market makers ██████████████████████████████████████████████████████

    /// @inheritdoc IRiseToken
    function push(
        uint256 _amountIn
    ) external whenInitialized returns (uint256 _amountOut) {
        /// ███ Checks
        if (leverageRatio() > minLeverageRatio) revert NoNeedToRebalance();
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
        if (_amountOut > maxBorrowAmount) revert SwapAmountTooLarge();

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
        if (leverageRatio() < maxLeverageRatio) revert NoNeedToRebalance();
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
        if (_amountIn > maxRepayAmount) revert SwapAmountTooLarge();

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
