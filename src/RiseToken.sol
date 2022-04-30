// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;


import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

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
    /// ███ Libraries ██████████████████████████████████████████████████████████

    using SafeERC20 for ERC20;
    using SafeERC20 for IWETH9;

    /// ███ Storages ███████████████████████████████████████████████████████████

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

    uint8 private immutable cdecimals;
    uint8 private immutable ddecimals;


    /// ███ Constructors ███████████████████████████████████████████████████████

    constructor(
        string memory _name,
        string memory _symbol,
        address _factory,
        address _fCollateral,
        address _fDebt,
        address _uniswapAdapter,
        address _oracleAdapter
    ) ERC20(_name, _symbol) {
        factory = RiseTokenFactory(_factory);
        uniswapAdapter = UniswapAdapter(_uniswapAdapter);
        oracleAdapter = RariFusePriceOracleAdapter(_oracleAdapter);
        fCollateral = IfERC20(_fCollateral);
        fDebt = IfERC20(_fDebt);
        collateral = ERC20(fCollateral.underlying());
        debt = ERC20(fDebt.underlying());
        weth = IWETH9(uniswapAdapter.weth());

        cdecimals = collateral.decimals();
        ddecimals = debt.decimals();

        transferOwnership(factory.owner());
    }


    /// ███ Internal functions █████████████████████████████████████████████████

    function supplyThenBorrow(uint256 _collateralAmount, uint256 _borrowAmount) internal {
        // Deposit to Rari Fuse
        collateral.safeIncreaseAllowance(address(fCollateral), _collateralAmount);
        uint256 fuseResponse;
        fuseResponse = fCollateral.mint(_collateralAmount);
        if (fuseResponse != 0) revert FuseError(fuseResponse);

        // Borrow from Rari Fuse
        fuseResponse = fDebt.borrow(_borrowAmount);
        if (fuseResponse != 0) revert FuseError(fuseResponse);

        // Cache the value
        totalCollateral = fCollateral.balanceOfUnderlying(address(this));
        totalDebt = fDebt.borrowBalanceCurrent(address(this));
    }

    function repayThenRedeem(uint256 _repayAmount, uint256 _collateralAmount) internal {
        // Repay debt to Rari Fuse
        debt.safeIncreaseAllowance(address(fDebt), _repayAmount);
        uint256 repayResponse = fDebt.repayBorrow(_repayAmount);
        if (repayResponse != 0) revert FuseError(repayResponse);

        // Redeem from Rari Fuse
        uint256 redeemResponse = fCollateral.redeemUnderlying(_collateralAmount);
        if (redeemResponse != 0) revert FuseError(redeemResponse);

        // Cache the value
        totalCollateral = fCollateral.balanceOfUnderlying(address(this));
        totalDebt = fDebt.borrowBalanceCurrent(address(this));
    }

    function onInitialize(uint256 _wethAmount, uint256 _collateralAmount, bytes memory _data) internal {
        isInitialized = true;
        (InitializeParams memory params) = abi.decode(_data, (InitializeParams));

        // Enter Rari Fuse Markets
        address[] memory markets = new address[](2);
        markets[0] = address(fCollateral);
        markets[1] = address(fDebt);
        uint256[] memory marketStatus = IFuseComptroller(fCollateral.comptroller()).enterMarkets(markets);
        if (marketStatus[0] != 0 && marketStatus[1] != 0) revert FuseError(marketStatus[0]);

        supplyThenBorrow(_collateralAmount, params.borrowAmount);

        // Swap debt asset to WETH
        debt.safeIncreaseAllowance(address(uniswapAdapter), params.borrowAmount);
        uint256 wethAmountFromBorrow = uniswapAdapter.swapExactTokensForWETH(address(debt)  , params.borrowAmount, 0);

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

    function onBuy(uint256 _wethAmount, uint256 _collateralAmount, bytes memory _data) internal {
        // Parse the data from buy function
        (BuyParams memory params) = abi.decode(_data, (BuyParams));

        // Supply then borrow in Rari Fuse
        supplyThenBorrow(_collateralAmount, params.debtAmount);

        // Swap debt asset to WETH
        debt.safeIncreaseAllowance(address(uniswapAdapter), params.debtAmount);
        uint256 wethAmountFromBorrow = uniswapAdapter.swapExactTokensForWETH(address(debt), params.debtAmount, 0);

        // Get owed WETH
        uint256 owedWETH = _wethAmount - wethAmountFromBorrow;

        if (address(params.tokenIn) == address(0)) {
            if (owedWETH > params.amountInMax) revert SlippageTooHigh();
            // Transfer excess ETH back to the buyer
            uint256 excessETH = params.amountInMax - owedWETH;
            (bool sent, ) = params.buyer.call{value: excessETH}("");
            if (!sent) revert FailedToSendETH(params.buyer, excessETH);
            weth.deposit{ value: owedWETH }();
        } else {
            params.tokenIn.safeTransferFrom(params.buyer, address(this), params.amountInMax);
            params.tokenIn.safeIncreaseAllowance(address(uniswapAdapter), params.amountInMax);
            uint256 amountIn = uniswapAdapter.swapTokensForExactWETH(address(params.tokenIn), owedWETH, params.amountInMax);
            if (amountIn < params.amountInMax) {
                params.tokenIn.safeTransfer(params.buyer, params.amountInMax - amountIn);
            }
        }

        // Transfer WETH to Uniswap Adapter to repay the flash swap
        weth.safeTransfer(address(uniswapAdapter), _wethAmount);

        // Mint the Rise Token to the buyer
        _mint(params.recipient, params.shares);
        _mint(factory.feeRecipient(), params.fee);

        emit Buy(params);
    }

    // Need this to handle debt token as output token; We can't re-enter the pool
    uint256 private wethLeftFromFlashSwap;

    function onSell(uint256 _wethAmount, uint256 _debtAmount, bytes memory _data) internal {
        // Parse the data from sell function
        (SellParams memory params) = abi.decode(_data, (SellParams));

        // Repay then redeem
        repayThenRedeem(_debtAmount, params.collateralAmount);

        // If tokenOut is collateral then don't swap all collateral to WETH
        if (address(params.tokenOut) == address(collateral)) {
            // Swap collateral to repay WETH
            collateral.safeIncreaseAllowance(address(uniswapAdapter), params.collateralAmount);
            uint256 collateralToBuyWETH = uniswapAdapter.swapTokensForExactWETH(address(collateral), _wethAmount, params.collateralAmount);
            uint256 collateralLeft = params.collateralAmount - collateralToBuyWETH;
            if (collateralLeft < params.amountOutMin) revert SlippageTooHigh();
            collateral.safeTransfer(params.recipient, collateralLeft);
        } else {
            // Swap all collateral to WETH
            collateral.safeIncreaseAllowance(address(uniswapAdapter), params.collateralAmount);
            uint256 wethAmountFromCollateral = uniswapAdapter.swapExactTokensForWETH(address(collateral), params.collateralAmount, 0);
            uint256 wethLeft = wethAmountFromCollateral - _wethAmount;

            if (address(params.tokenOut) == address(0)) {
                if (wethLeft < params.amountOutMin) revert SlippageTooHigh();
                weth.safeIncreaseAllowance(address(weth), wethLeft);
                weth.withdraw(wethLeft);
                (bool sent, ) = params.recipient.call{value: wethLeft}("");
                if (!sent) revert FailedToSendETH(params.recipient, wethLeft);
            }

            // Cannot enter the pool again
            if (address(params.tokenOut) == address(debt)) {
                wethLeftFromFlashSwap = wethLeft;
            }

            if (address(params.tokenOut) != address(0) && (address(params.tokenOut) != address(debt))) {
                weth.safeIncreaseAllowance(address(uniswapAdapter), wethLeft);
                uint256 amountOut = uniswapAdapter.swapExactWETHForTokens(address(params.tokenOut), wethLeft, params.amountOutMin);
                params.tokenOut.safeTransfer(params.recipient, amountOut);
            }
        }

        // Transfer WETH to uniswap adapter
        weth.safeTransfer(address(uniswapAdapter), _wethAmount);

        // Burn the Rise Token
        ERC20(address(this)).safeTransferFrom(params.seller, factory.feeRecipient(), params.fee);
        _burn(params.seller, params.shares - params.fee);
        emit Sell(params);
    }


    /// ███ Owner actions ██████████████████████████████████████████████████████

    /// @inheritdoc IRiseToken
    function setParams(uint256 _minLeverageRatio, uint256 _maxLeverageRatio, uint256 _step, uint256 _discount, uint256 _newMaxBuy) external onlyOwner {
        minLeverageRatio = _minLeverageRatio;
        maxLeverageRatio = _maxLeverageRatio;
        step = _step;
        discount = _discount;
        maxBuy = _newMaxBuy;
        emit ParamsUpdated(minLeverageRatio, maxLeverageRatio, step, discount, maxBuy);
    }

    /// @inheritdoc IRiseToken
    function initialize(InitializeParams memory _params) external payable onlyOwner {
        if (isInitialized == true) revert AlreadyInitialized();
        if (msg.value == 0) revert InputAmountInvalid();
        _params.ethAmount = msg.value;
        bytes memory data = abi.encode(FlashSwapType.Initialize, abi.encode(_params));
        uniswapAdapter.flashSwapWETHForExactTokens(address(collateral), _params.collateralAmount, data);
    }


    /// ███ External functions █████████████████████████████████████████████████

    function onFlashSwapWETHForExactTokens(uint256 _wethAmount, uint256 _amountOut, bytes calldata _data) external {
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

    /// ███ Read-only functions ████████████████████████████████████████████████

    function decimals() public view virtual override returns (uint8) {
        return cdecimals;
    }

    /// @inheritdoc IRiseToken
    function collateralPerShare() public view returns (uint256 _cps) {
        if (!isInitialized) return 0;
        _cps = (totalCollateral * (10**cdecimals)) / totalSupply();
    }

    /// @inheritdoc IRiseToken
    function debtPerShare() public view returns (uint256 _dps) {
        if (!isInitialized) return 0;
        _dps = (totalDebt * (10**cdecimals)) / totalSupply();
    }

    /// @inheritdoc IRiseToken
    function value(uint256 _shares) public view returns (uint256 _value) {
        if (!isInitialized) return 0;
        if (_shares == 0) return 0;
        // Get the collateral & debt amount
        uint256 collateralAmount = (_shares * collateralPerShare()) / (10**cdecimals);
        uint256 debtAmount = (_shares * debtPerShare()) / (10**cdecimals);

        // Get the price in ETH
        uint256 cPrice = oracleAdapter.price(address(collateral));
        uint256 dPrice = oracleAdapter.price(address(debt));

        // Get total value in ETH
        uint256 collateralValue = (collateralAmount * cPrice) / (10**cdecimals);
        uint256 debtValue = (debtAmount * dPrice) / (10**ddecimals);

        // Get Rise Token value in ETH
        _value = collateralValue - debtValue;
    }

    /// @inheritdoc IRiseToken
    function value(uint256 _shares, address _quote) public view returns (uint256 _value) {
        uint256 valueInETH = value(_shares);
        if (valueInETH == 0) return 0;
        uint256 quoteDecimals = ERC20(_quote).decimals();
        uint256 quotePrice = oracleAdapter.price(_quote);
        uint256 amountInETH = (valueInETH * 1e18) / quotePrice;

        // Get Rise Token value in _quote token
        _value = (amountInETH * (10**quoteDecimals)) / 1e18;
    }

    /// @inheritdoc IRiseToken
    function nav() public view returns (uint256 _nav) {
        if (!isInitialized) return 0;
        _nav = value(10**cdecimals);
    }

    /// @inheritdoc IRiseToken
    function leverageRatio() public view returns (uint256 _lr) {
        if (!isInitialized) return 0;
        uint256 collateralPrice = oracleAdapter.price(address(collateral));
        uint256 collateralValue = (collateralPerShare() * collateralPrice) / (10**cdecimals);
        _lr = (collateralValue * 1e18) / nav();
    }


    /// ███ User actions ███████████████████████████████████████████████████████

    /// @inheritdoc IRiseToken
    function buy(uint256 _shares, address _recipient, address _tokenIn, uint256 _amountInMax) external payable {
        if (!isInitialized) revert NotInitialized();
        if (_shares > maxBuy) revert InputAmountInvalid();

        uint256 fee = ((fees * _shares) / 1e18);
        uint256 newShares = _shares + fee;
        BuyParams memory params = BuyParams({
            buyer: msg.sender,
            recipient: _recipient,
            tokenIn: ERC20(_tokenIn),
            amountInMax: _tokenIn == address(0) ? msg.value : _amountInMax,
            shares: _shares,
            collateralAmount: (newShares * collateralPerShare()) / (10**cdecimals),
            debtAmount: (newShares * debtPerShare()) / (10**cdecimals),
            fee: fee,
            nav: nav()
        });

        // Perform the flash swap
        bytes memory data = abi.encode(FlashSwapType.Buy, abi.encode(params));
        uniswapAdapter.flashSwapWETHForExactTokens(address(collateral), params.collateralAmount, data);
    }

    /// @inheritdoc IRiseToken
    function sell(uint256 _shares, address _recipient, address _tokenOut, uint256 _amountOutMin) external {
        if (!isInitialized) revert NotInitialized();

        uint256 fee = ((fees * _shares) / 1e18);
        uint256 newShares = _shares - fee;
        SellParams memory params = SellParams({
            seller: msg.sender,
            recipient: _recipient,
            tokenOut: ERC20(_tokenOut),
            amountOutMin: _amountOutMin,
            shares: _shares,
            collateralAmount: (newShares * collateralPerShare()) / (10**cdecimals),
            debtAmount: (newShares * debtPerShare()) / (10**cdecimals),
            fee: fee,
            nav: nav()
        });

        // Perform the flash swap
        bytes memory data = abi.encode(FlashSwapType.Sell, abi.encode(params));
        uniswapAdapter.flashSwapWETHForExactTokens(address(debt), params.debtAmount, data);

        if (address(params.tokenOut) == address(debt)) {
            weth.safeIncreaseAllowance(address(uniswapAdapter), wethLeftFromFlashSwap);
            uint256 amountOut = uniswapAdapter.swapExactWETHForTokens(address(params.tokenOut), wethLeftFromFlashSwap, params.amountOutMin);
            params.tokenOut.safeTransfer(params.recipient, amountOut);
            wethLeftFromFlashSwap = 0;
        }
    }


    /// ███ Market makers ██████████████████████████████████████████████████████

    /// @inheritdoc IRiseToken
    function swapExactCollateralForETH(uint256 _amountIn, uint256 _amountOutMin) external returns (uint256 _amountOut) {
        /// ███ Checks
        if (leverageRatio() > minLeverageRatio) revert NoNeedToRebalance();
        if (_amountIn == 0) return 0;

        // Discount the price
        uint256 price = oracleAdapter.price(address(collateral));
        price += (discount * price) / 1e18;
        _amountOut = (_amountIn * price) / (1e18);
        if (_amountOut < _amountOutMin) revert SlippageTooHigh();

        /// ███ Effects

        // Transfer collateral to the contract
        collateral.safeTransferFrom(msg.sender, address(this), _amountIn);

        // This is our buying power; can't buy collateral more than this
        uint256 borrowAmount = ((step * value((10**cdecimals), address(debt)) / 1e18) * totalSupply()) / (10**cdecimals);
        supplyThenBorrow(_amountIn, borrowAmount);

        // This will revert if _amountOut is too large; we can't buy the _amountIn
        debt.safeIncreaseAllowance(address(uniswapAdapter), borrowAmount);
        uint256 amountIn = uniswapAdapter.swapTokensForExactWETH(address(debt), _amountOut, borrowAmount);

        // If amountIn < borrow; then send back debt token to Rari Fuse
        if (amountIn < borrowAmount) {
            uint256 repayAmount = borrowAmount - amountIn;
            debt.safeIncreaseAllowance(address(fDebt), repayAmount);
            uint256 repayResponse = fDebt.repayBorrow(repayAmount);
            if (repayResponse != 0) revert FuseError(repayResponse);
            totalDebt = fDebt.borrowBalanceCurrent(address(this));
        }

        // Convert WETH to ETH
        weth.safeIncreaseAllowance(address(weth), _amountOut);
        weth.withdraw(_amountOut);

        /// ███ Interactions
        (bool sent, ) = msg.sender.call{value: _amountOut}("");
        if (!sent) revert FailedToSendETH(msg.sender, _amountOut);
    }

    /// @inheritdoc IRiseToken
    function swapExactETHForCollateral(uint256 _amountOutMin) external payable returns (uint256 _amountOut) {
        /// ███ Checks
        if (leverageRatio() < maxLeverageRatio) revert NoNeedToRebalance();
        if (msg.value == 0) return 0;

        // Discount the price
        uint256 price = oracleAdapter.price(address(collateral));
        price -= (discount * price) / 1e18;
        _amountOut = (msg.value * (10**cdecimals)) / price;
        if (_amountOut < _amountOutMin) revert SlippageTooHigh();

        // Convert ETH to WETH
        weth.deposit{value: msg.value}();

        // This is our selling power, can't sell more than this
        uint256 repayAmount = ((step * value((10**cdecimals), address(debt)) / 1e18) * totalSupply()) / (10**cdecimals);
        weth.safeIncreaseAllowance(address(uniswapAdapter), msg.value);
        uint256 repayAmountFromETH = uniswapAdapter.swapExactWETHForTokens(address(debt), msg.value, 0);
        if (repayAmountFromETH > repayAmount) revert LiquidityIsNotEnough();

        /// ███ Effects
        repayThenRedeem(repayAmountFromETH, _amountOut);

        /// ███ Interactions
        collateral.safeTransfer(msg.sender, _amountOut);
    }

    receive() external payable {}
}
