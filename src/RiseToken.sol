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

    IWETH9                     public immutable weth;
    RiseTokenFactory           public immutable factory;
    UniswapAdapter             public immutable uniswapAdapter;
    RariFusePriceOracleAdapter public immutable oracleAdapter;

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


    /// ███ Constructor ██████████████████████████████████████████████████████

    constructor(
        string memory _name,
        string memory _symbol,
        RiseTokenFactory _factory,
        IfERC20 _fCollateral,
        IfERC20 _fDebt,
        UniswapAdapter _uniswapAdapter,
        RariFusePriceOracleAdapter _oracleAdapter
    ) ERC20(_name, _symbol) {
        factory = _factory;
        uniswapAdapter = _uniswapAdapter;
        oracleAdapter = _oracleAdapter;
        fCollateral = _fCollateral;
        fDebt = _fDebt;
        collateral = ERC20(fCollateral.underlying());
        debt = ERC20(fDebt.underlying());
        weth = IWETH9(uniswapAdapter.weth());

        transferOwnership(factory.owner());
    }


    /// ███ Internal functions █████████████████████████████████████████████████

    function supplyThenBorrow(uint256 _cAmount, uint256 _bAmount) internal {
        // Deposit to Rari Fuse
        collateral.safeIncreaseAllowance(address(fCollateral), _cAmount);
        uint256 fuseResponse;
        fuseResponse = fCollateral.mint(_cAmount);
        if (fuseResponse != 0) revert FuseError(fuseResponse);
        totalCollateral = fCollateral.balanceOfUnderlying(address(this));

        // Borrow from Rari Fuse
        if (_bAmount == 0) return;
        fuseResponse = fDebt.borrow(_bAmount);
        if (fuseResponse != 0) revert FuseError(fuseResponse);
        totalDebt = fDebt.borrowBalanceCurrent(address(this));
    }

    function repayThenRedeem(uint256 _rAmount, uint256 _cAmount) internal {
        // Repay debt to Rari Fuse
        debt.safeIncreaseAllowance(address(fDebt), _rAmount);
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
        uint256 _wethAmount,
        uint256 _collateralAmount,
        bytes memory _data
    ) internal {
        isInitialized = true;
        (InitializeParams memory params) = abi.decode(_data, (InitializeParams));

        // Enter Rari Fuse Markets
        address[] memory markets = new address[](2);
        markets[0] = address(fCollateral);
        markets[1] = address(fDebt);
        IFuseComptroller troll = IFuseComptroller(fCollateral.comptroller());
        uint256[] memory res = troll.enterMarkets(markets);
        if (res[0] != 0 && res[1] != 0) revert FuseError(res[0]);

        supplyThenBorrow(_collateralAmount, params.borrowAmount);

        // Swap debt asset to WETH
        debt.safeIncreaseAllowance(address(uniswapAdapter), params.borrowAmount);
        uint256 wethAmountFromBorrow = uniswapAdapter.swapExactTokensForWETH(
            address(debt),
            params.borrowAmount,
            0
        );

        // Get owed WETH
        uint256 owedWETH = _wethAmount - wethAmountFromBorrow;
        if (owedWETH > params.ethAmount) revert SlippageTooHigh();

        // Transfer excess ETH back to the initializer
        uint256 excessETH = params.ethAmount - owedWETH;
        (bool sent, ) = params.initializer.call{value: excessETH}("");
        if (!sent) revert FailedToSendETH(params.initializer, excessETH);

        // Send back WETH to uniswap adapter
        weth.deposit{ value: owedWETH }(); // Wrap the ETH to WETH
        weth.safeTransfer(address(uniswapAdapter), _wethAmount);

        // Mint the Rise Token to the initializer
        _mint(params.initializer, params.shares);

        emit Initialized(params);
    }

    /// @notice We need this in order to allow user buy using any token
    uint256 private wethLeftAfterFlashSwap;

    function onBuy(
        uint256 _wethRepayAmount,
        uint256 _collateralAmount,
        bytes memory _data
    ) internal {
        // Parse the data from buy function
        BuyParams memory params = abi.decode(_data, (BuyParams));

        // Supply then borrow in Rari Fuse
        supplyThenBorrow(_collateralAmount, params.debtAmount);

        // Swap debt asset to WETH
        debt.safeIncreaseAllowance(address(uniswapAdapter), params.debtAmount);
        uint256 wethAmountFromBorrow = uniswapAdapter.swapExactTokensForWETH(
            address(debt),
            params.debtAmount,
            0
        );

        uint256 wethAmountIn = params.wethAmount + wethAmountFromBorrow;
        if (_wethRepayAmount > wethAmountIn) revert SlippageTooHigh();
        wethLeftAfterFlashSwap = wethAmountIn - _wethRepayAmount;

        // Transfer WETH to Uniswap Adapter to repay the flash swap
        weth.safeTransfer(address(uniswapAdapter), _wethRepayAmount);

        // Mint the Rise Token to the buyer
        _mint(params.recipient, params.shares);
        _mint(factory.feeRecipient(), params.fee);
    }

    /// @notice We need this in order to allow user selling to any token
    uint256 private collateralLeftAfterFlashSwap;

    function onSell(
        uint256 _wethRepayAmount,
        uint256 _debtAmount,
        bytes memory _data
    ) internal {
        // Parse the data from sell function
        (SellParams memory params) = abi.decode(_data, (SellParams));

        // Transfer fee and burn the Rise Token
        _transfer(params.seller, factory.feeRecipient(), params.fee);
        _burn(params.seller, params.shares - params.fee);

        // Repay then redeem
        repayThenRedeem(_debtAmount, params.collateralAmount);

        // Swap collateral token to WETH
        collateral.safeIncreaseAllowance(address(uniswapAdapter), params.collateralAmount);
        uint256 collateralSold = uniswapAdapter.swapTokensForExactWETH(
            address(collateral),
            _wethRepayAmount,
            params.collateralAmount
        );
        collateralLeftAfterFlashSwap = params.collateralAmount - collateralSold;

        // Repay the flash swap
        weth.safeTransfer(address(uniswapAdapter), _wethRepayAmount);
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
        minLeverageRatio = _minLeverageRatio;
        maxLeverageRatio = _maxLeverageRatio;
        step = _step;
        discount = _discount;
        maxBuy = _newMaxBuy;
        emit ParamsUpdated(minLeverageRatio, maxLeverageRatio, step, discount, maxBuy);
    }

    /// @inheritdoc IRiseToken
    function initialize(
        InitializeParams memory _params
    ) external payable onlyOwner {
        if (isInitialized == true) revert AlreadyInitialized();
        if (msg.value == 0) revert InitializeAmountInInvalid();
        _params.ethAmount = msg.value;
        _params.initializer = msg.sender;
        bytes memory data = abi.encode(
            FlashSwapType.Initialize,
            abi.encode(_params)
        );
        uniswapAdapter.flashSwapWETHForExactTokens(
            address(collateral),
            _params.collateralAmount,
            data
        );
    }


    /// ███ External functions ███████████████████████████████████████████████

    function onFlashSwapWETHForExactTokens(
        uint256 _wethAmount,
        uint256 _amountOut,
        bytes calldata _data
    ) external {
        if (msg.sender != address(uniswapAdapter)) revert NotUniswapAdapter();

        // Continue execution based on the type
        (FlashSwapType flashSwapType, bytes memory data) = abi.decode(_data, (FlashSwapType,bytes));
        if (flashSwapType == FlashSwapType.Initialize) {
            onInitialize(_wethAmount, _amountOut, data);
            return;
        }

        if (flashSwapType == FlashSwapType.Buy) {
            onBuy(_wethAmount, _amountOut, data);
            return;
        }

        if (flashSwapType == FlashSwapType.Sell) {
            onSell(_wethAmount, _amountOut, data);
            return;
        }
    }


    /// ███ Read-only functions ██████████████████████████████████████████████

    /// @inheritdoc IRiseToken
    function collateralPerShare() public view returns (uint256 _cps) {
        if (!isInitialized) return 0;
        _cps = totalCollateral.divWadUp(totalSupply());
    }

    /// @inheritdoc IRiseToken
    function debtPerShare() public view returns (uint256 _dps) {
        if (!isInitialized) return 0;
        _dps = totalDebt.divWadUp(totalSupply());
    }

    /// @inheritdoc IRiseToken
    function value(uint256 _shares) public view returns (uint256 _value) {
        if (!isInitialized) return 0;
        if (_shares == 0) return 0;

        // Get the collateral & debt amount
        uint256 cAmount = _shares.mulDivDown(totalCollateral, totalSupply());
        uint256 dAmount = _shares.mulDivDown(totalDebt, totalSupply());

        // Get the collateral value
        uint256 cv = oracleAdapter.totalValue(
            address(collateral),
            address(debt),
            cAmount
        );

        // Get total value in terms of debt token
        _value = cv - dAmount;
    }

    /// @inheritdoc IRiseToken
    function nav() public view returns (uint256 _nav) {
        if (!isInitialized) return 0;
        _nav = value(1 ether);
    }

    /// @inheritdoc IRiseToken
    function leverageRatio() public view returns (uint256 _lr) {
        if (!isInitialized) return 0;
        uint256 cv = oracleAdapter.totalValue(
            address(collateral),
            address(debt),
            totalCollateral
        );
        _lr = cv.divWadUp(cv - totalDebt);
    }


    /// ███ User actions █████████████████████████████████████████████████████

    /// @inheritdoc IRiseToken
    function buy(
        uint256 _shares,
        address _recipient,
        address _tokenIn,
        uint256 _amountInMax
    ) external payable returns (uint256 _amountIn) {
        /// ███ Checks
        if (!isInitialized) revert NotInitialized();
        if (_shares > maxBuy) revert SwapAmountTooLarge();

        /// ███ Effects

        // Convert tokenIn to WETH to repay flash swap; We do it here coz
        // we can't re-enter the pool if tokenIn is collateral token
        uint256 wethAmount = msg.value;
        if (_tokenIn == address(0)) {
            weth.deposit{ value: msg.value}();
        } else {
            ERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountInMax);
            ERC20(_tokenIn).safeIncreaseAllowance(address(uniswapAdapter), _amountInMax);
            wethAmount = uniswapAdapter.swapExactTokensForWETH(
                _tokenIn,
                _amountInMax,
                0
            );
        }

        uint256 fee = fees.mulWadDown(_shares);
        uint256 newShares = _shares + fee;
        BuyParams memory params = BuyParams({
            buyer: msg.sender,
            recipient: _recipient,
            wethAmount: wethAmount,
            shares: _shares,
            collateralAmount: newShares.mulDivDown(totalCollateral, totalSupply()),
            debtAmount: newShares.mulDivDown(totalDebt, totalSupply()),
            fee: fee,
            nav: nav()
        });

        bytes memory data = abi.encode(FlashSwapType.Buy, abi.encode(params));
        uniswapAdapter.flashSwapWETHForExactTokens(
            address(collateral),
            params.collateralAmount,
            data
        );

        /// ███ Interactions
        // Check after flash swap; Refund the token
        _amountIn = _tokenIn == address(0) ? msg.value : _amountInMax;
        if (wethLeftAfterFlashSwap > 0) {
            uint256 wethLeft = wethLeftAfterFlashSwap;
            wethLeftAfterFlashSwap = 0;
            if (_tokenIn == address(0)) {
                weth.safeIncreaseAllowance(address(weth), wethLeft);
                weth.withdraw(wethLeft);
                _amountIn = msg.value - wethLeft;
                (bool sent, ) = msg.sender.call{value: wethLeft}("");
                if (!sent) revert FailedToSendETH(msg.sender, wethLeft);
            } else {
                weth.safeIncreaseAllowance(address(uniswapAdapter), wethLeft);
                uint256 excess = uniswapAdapter.swapExactWETHForTokens(
                    _tokenIn,
                    wethLeft,
                    0
                );
                _amountIn = _amountInMax - excess;
                ERC20(_tokenIn).safeTransfer(msg.sender, excess);
            }
        }
        emit Buy(params);
    }

    /// @inheritdoc IRiseToken
    function sell(
        uint256 _shares,
        address _recipient,
        address _tokenOut,
        uint256 _amountOutMin
    ) external returns (uint256 _amountOut) {
        if (!isInitialized) revert NotInitialized();

        uint256 fee = fees.mulWadDown(_shares);
        uint256 newShares = _shares - fee;
        SellParams memory params = SellParams({
            seller: msg.sender,
            recipient: _recipient,
            shares: _shares,
            collateralAmount: newShares.mulDivDown(totalCollateral, totalSupply()),
            debtAmount: newShares.mulDivDown(totalDebt, totalSupply()),
            fee: fee,
            nav: nav()
        });

        // Perform the flash swap
        bytes memory data = abi.encode(FlashSwapType.Sell, abi.encode(params));
        uniswapAdapter.flashSwapWETHForExactTokens(
            address(debt),
            params.debtAmount,
            data
        );

        if (collateralLeftAfterFlashSwap == 0) revert SlippageTooHigh();
        uint256 cleft = collateralLeftAfterFlashSwap;
        collateralLeftAfterFlashSwap = 0;

        if (_tokenOut == address(collateral)) {
            if (_amountOutMin > cleft) revert SlippageTooHigh();
            collateral.safeTransfer(_recipient, cleft);
            _amountOut = cleft;
        } else {
            collateral.safeIncreaseAllowance(address(uniswapAdapter), cleft);
            uint256 wethOut = uniswapAdapter.swapExactTokensForWETH(
                address(collateral),
                cleft,
                0
            );
            if (_tokenOut == address(0)) {
                _amountOut = wethOut;
                if (_amountOutMin > _amountOut) revert SlippageTooHigh();
                weth.withdraw(_amountOut);
                (bool sent, ) = _recipient.call{value: _amountOut}("");
                if (!sent) revert FailedToSendETH(_recipient, _amountOut);
            } else {
                // Swap WETH to tokenOut
                weth.safeIncreaseAllowance(address(uniswapAdapter), wethOut);
                _amountOut = uniswapAdapter.swapExactWETHForTokens(
                    _tokenOut,
                    wethOut,
                    0
                );
                if (_amountOutMin > _amountOut) revert SlippageTooHigh();
                ERC20(_tokenOut).safeTransfer(_recipient, _amountOut);
            }
        }
        emit Sell(params);
    }


    /// ███ Market makers ██████████████████████████████████████████████████████

    /// @inheritdoc IRiseToken
    function push(uint256 _amountIn) external returns (uint256 _amountOut) {
        /// ███ Checks
        if (leverageRatio() > minLeverageRatio) revert NoNeedToRebalance();
        if (_amountIn == 0) return 0;

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
    }

    /// @inheritdoc IRiseToken
    function pull(uint256 _amountOut) external returns (uint256 _amountIn) {
        /// ███ Checks
        if (leverageRatio() < maxLeverageRatio) revert NoNeedToRebalance();
        if (_amountOut == 0) return 0;

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
    }

    receive() external payable {}
}
