// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

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

    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH9;

    /// ███ Storages ███████████████████████████████████████████████████████████

    /// @notice WETH address
    IWETH9 public weth;

    /// @notice The Rise Token Factory
    RiseTokenFactory public immutable factory;

    /// @notice Uniswap Adapter
    UniswapAdapter public uniswapAdapter;

    /// @notice Rari Fuse Price Oracle Adapter
    RariFusePriceOracleAdapter public oracleAdapter;

    /// @notice The ERC20 compliant token that used by FLT as collateral asset
    IERC20 public immutable collateral;

    /// @notice The ERC20 compliant token that used by FLT as debt asset
    IERC20 public immutable debt;

    /// @notice The Rari Fuse collateral token
    IfERC20 public immutable fCollateral;

    /// @notice The Rari Fuse debt token
    IfERC20 public immutable fDebt;

    /// @notice True if the total collateral and debt are bootstraped
    bool public isInitialized;

    /// @notice Cache the total collateral from Rari Fuse
    /// @dev We need this because balanceOfUnderlying fToken is a non-view function
    uint256 public totalCollateral;
    uint256 public totalDebt;

    /**
     * @notice The maximum amount of total supply that can be minted in one transaction.
     *         - There is no limit by default (2**256-1).
     *         - Owner can set maxBuy to zero to disable the deposit if
     *           something bad happen
     */
    uint256 public maxBuy = type(uint256).max;

    /// @notice Fees in 1e18 precision (e.g. 0.1% is 0.001 * 1e8)
    uint256 public fees = 0.001 ether;

    /// @notice Minimum leverage ratio in 1e18 precision
    uint256 public minLeverageRatio = 1.7 ether;

    /// @notice Maximum leverage ratio in 1e18 precision
    uint256 public maxLeverageRatio = 2.3 ether;

    /// @notice Rebalancing step in 1e18 precision
    uint256 public step = 0.2 ether;

    /// @notice Max rebalancing value in debt decimals precision
    uint256 public maxRebalanceValue;

    /// @notice The collateral decimals
    uint8 private cdecimals;

    /// @notice The debt decimals
    uint8 private ddecimals;


    /// ███ Constructors ███████████████████████████████████████████████████████

    constructor(string memory _name, string memory _symbol, address _factory, address _fCollateral, address _fDebt) ERC20(_name, _symbol) {
        // Set the storages
        factory = RiseTokenFactory(_factory);
        uniswapAdapter = factory.uniswapAdapter();
        oracleAdapter = factory.oracleAdapter();
        fCollateral = IfERC20(_fCollateral);
        fDebt = IfERC20(_fDebt);
        collateral = IERC20(fCollateral.underlying());
        debt = IERC20(fDebt.underlying());
        weth = IWETH9(uniswapAdapter.weth());

        // Get the collateral & debt decimals
        cdecimals = IERC20Metadata(address(collateral)).decimals();
        ddecimals = IERC20Metadata(address(debt)).decimals();

        // Transfer ownership to factory owner
        transferOwnership(factory.owner());
    }


    /// ███ Internal functions █████████████████████████████████████████████████

    function supplyThenBorrow(uint256 _collateralAmount, uint256 _borrowAmount) internal {
        // Deposit all collateral to Rari Fuse
        collateral.safeIncreaseAllowance(address(fCollateral), _collateralAmount);
        uint256 supplyResponse = fCollateral.mint(_collateralAmount);
        if (supplyResponse != 0) revert FuseAddCollateralFailed(supplyResponse);

        // Borrow from Rari Fuse
        uint256 borrowResponse = fDebt.borrow(_borrowAmount);
        if (borrowResponse != 0) revert FuseBorrowFailed(borrowResponse);

        // Cache the value
        totalCollateral = fCollateral.balanceOfUnderlying(address(this));
        totalDebt = fDebt.borrowBalanceCurrent(address(this));
    }

    function repayThenRedeem(uint256 _repayAmount, uint256 _collateralAmount) internal {
        // Repay the debt to Rari Fuse
        debt.safeIncreaseAllowance(address(fDebt), _repayAmount);
        uint256 repayResponse = fDebt.repayBorrow(_repayAmount);
        if (repayResponse != 0) revert FuseRepayDebtFailed(repayResponse);

        // Redeem from Rari Fuse
        uint256 redeemResponse = fCollateral.redeemUnderlying(_collateralAmount);
        if (redeemResponse != 0) revert FuseRedeemCollateralFailed(redeemResponse);

        // Cache the value
        totalCollateral = fCollateral.balanceOfUnderlying(address(this));
        totalDebt = fDebt.borrowBalanceCurrent(address(this));
    }

    function onInitialize(uint256 _wethAmount, uint256 _collateralAmount, bytes memory _data) internal {
        /// ███ Effects
        isInitialized = true;

        /// ███ Interactions

        // Parse the data from initialize() function
        (InitializeParams memory params) = abi.decode(_data, (InitializeParams));

        // Enter Rari Fuse Markets
        address[] memory markets = new address[](2);
        markets[0] = address(fCollateral);
        markets[1] = address(fDebt);
        uint256[] memory marketStatus = IFuseComptroller(fCollateral.comptroller()).enterMarkets(markets);
        if (marketStatus[0] != 0 && marketStatus[1] != 0) revert FuseFailedToEnterMarkets(marketStatus[0], marketStatus[1]);

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
        /// ███ Interactions

        // Parse the data from bootstrap function
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

        // Transder WETH to Uniswap Adapter to repay the flash swap
        weth.safeTransfer(address(uniswapAdapter), _wethAmount);

        // Mint the Rise Token to the buyer
        _mint(params.recipient, params.shares);
        _mint(factory.feeRecipient(), params.fee);

        emit Buy(params);
    }

    // Need this to handle debt token as output token; We can't re-enter the pool
    uint256 private wethLeftFromFlashSwap;

    function onSell(uint256 _wethAmount, uint256 _debtAmount, bytes memory _data) internal {
        /// ███ Interactions

        // Parse the data from bootstrap function
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
        IERC20(address(this)).safeTransferFrom(params.seller, factory.feeRecipient(), params.fee);
        _burn(params.seller, params.shares - params.fee);
        emit Sell(params);
    }

    function value(uint256 _shares) internal view returns (uint256 _value) {
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

        // Get value in ETH
        _value = collateralValue - debtValue;
    }

    function value(uint256 _shares, address _quote) internal view returns (uint256 _value) {
        uint256 valueInETH = value(_shares);
        if (valueInETH == 0) return 0;
        uint256 quoteDecimals = IERC20Metadata(_quote).decimals();
        uint256 quotePrice = oracleAdapter.price(_quote);
        uint256 amountInETH = (valueInETH * 1e18) / quotePrice;
        _value = (amountInETH * (10**quoteDecimals)) / 1e18;
    }


    /// ███ Owner actions ██████████████████████████████████████████████████████

    /// @inheritdoc IRiseToken
    function setMaxBuy(uint256 _newMaxBuy) external onlyOwner {
        maxBuy = _newMaxBuy;
        emit MaxBuyUpdated(_newMaxBuy);
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
    function nav() public view returns (uint256 _nav) {
        if (!isInitialized) return 0;
        _nav = value(10**cdecimals);
    }

    /// @inheritdoc IRiseToken
    function nav(address _quote) public view returns (uint256 _nav) {
        uint256 quoteDecimals = IERC20Metadata(_quote).decimals();
        uint256 navInETH = nav();
        uint256 quotePrice = oracleAdapter.price(_quote);
        uint256 amountInETH = (navInETH * 1e18) / quotePrice;
        _nav = (amountInETH * (10**quoteDecimals)) / 1e18;
    }

    /// @inheritdoc IRiseToken
    function leverageRatio() public view returns (uint256 _lr) {
        if (!isInitialized) return 0;
        uint256 collateralPrice = oracleAdapter.price(address(collateral));
        uint256 collateralValue = (collateralPerShare() * collateralPrice) / (10**cdecimals);
        _lr = (collateralValue * 1e18) / nav();
    }

    /// @inheritdoc IRiseToken
    function previewBuy(uint256 _shares) public view returns (uint256 _ethAmount) {
        if (_shares == 0) return 0;
        if (!isInitialized) return 0;
        uint256 fee = ((fees * _shares) / 1e18);
        uint256 newShares = _shares + fee;
        _ethAmount = value(newShares);
    }

    /// @inheritdoc IRiseToken
    function previewBuy(uint256 _shares, address _tokenIn) external view returns (uint256 _amountIn) {
        if (_shares == 0) return 0;
        if (!isInitialized) return 0;
        uint256 fee = ((fees * _shares) / 1e18);
        uint256 newShares = _shares + fee;
        _amountIn = value(newShares, _tokenIn);
    }

    /// @inheritdoc IRiseToken
    function previewSell(uint256 _shares) public view returns (uint256 _ethAmount) {
        if (_shares == 0) return 0;
        if (!isInitialized) return 0;
        uint256 fee = ((fees * _shares) / 1e18);
        uint256 newShares = _shares - fee;
        _ethAmount = value(newShares);
    }

    /// @inheritdoc IRiseToken
    function previewSell(uint256 _shares, address _tokenOut) external view returns (uint256 _amountOut) {
        if (_shares == 0) return 0;
        if (!isInitialized) return 0;
        uint256 fee = ((fees * _shares) / 1e18);
        uint256 newShares = _shares - fee;
        _amountOut = value(newShares, _tokenOut);
    }


    /// ███ User actions ███████████████████████████████████████████████████████

    /// @notice Buy Rise Token using ETH or ERC20
    function buy(BuyParams memory params) internal {
        if (!isInitialized) revert NotInitialized();
        if (params.shares > maxBuy) revert InputAmountInvalid();

        // Add fees
        uint256 fee = ((fees * params.shares) / 1e18);
        uint256 newShares = params.shares + fee;

        // Get the collateral & debt amount
        uint256 collateralAmount = (newShares * collateralPerShare()) / (10**cdecimals);
        uint256 debtAmount = (newShares * debtPerShare()) / (10**cdecimals);

        // Update params
        params.fee = fee;
        params.collateralAmount = collateralAmount;
        params.debtAmount = debtAmount;

        // Perform the flash swap
        bytes memory data = abi.encode(FlashSwapType.Buy, abi.encode(params));
        uniswapAdapter.flashSwapWETHForExactTokens(address(collateral), collateralAmount, data);
    }

    /// @inheritdoc IRiseToken
    function buy(uint256 _shares, address _recipient) external payable {
        BuyParams memory params = BuyParams({
            buyer: msg.sender,
            recipient: _recipient,
            tokenIn: IERC20(address(0)),
            amountInMax: msg.value,
            shares: _shares,
            collateralAmount: 0,
            debtAmount: 0,
            fee: 0,
            nav: nav()
        });
        buy(params);
    }

    /// @inheritdoc IRiseToken
    function buy(uint256 _shares, address _recipient, address _tokenIn, uint256 _amountInMax) external {
        BuyParams memory params = BuyParams({
            buyer: msg.sender,
            recipient: _recipient,
            tokenIn: IERC20(_tokenIn),
            amountInMax: _amountInMax,
            shares: _shares,
            collateralAmount: 0,
            debtAmount: 0,
            fee: 0,
            nav: nav()
        });
        buy(params);
    }

    /// @notice Sell Rise Token for ETH or ERC20
    function sell(SellParams memory params) internal {
        // Check initialize status
        if (!isInitialized) revert NotInitialized();

        // Add fees
        uint256 fee = ((fees * params.shares) / 1e18);
        uint256 newShares = params.shares - fee;

        // Get the collateral & debt amount
        uint256 collateralAmount = (newShares * collateralPerShare()) / (10**cdecimals);
        uint256 debtAmount = (newShares * debtPerShare()) / (10**cdecimals);

        // Update params
        params.fee = fee;
        params.collateralAmount = collateralAmount;
        params.debtAmount = debtAmount;

        // Perform the flash swap
        bytes memory data = abi.encode(FlashSwapType.Sell, abi.encode(params));
        uniswapAdapter.flashSwapWETHForExactTokens(address(debt), debtAmount, data);

        if (address(params.tokenOut) == address(debt)) {
            weth.safeIncreaseAllowance(address(uniswapAdapter), wethLeftFromFlashSwap);
            uint256 amountOut = uniswapAdapter.swapExactWETHForTokens(address(params.tokenOut), wethLeftFromFlashSwap, params.amountOutMin);
            params.tokenOut.safeTransfer(params.recipient, amountOut);
            wethLeftFromFlashSwap = 0;
        }
    }

    /// @inheritdoc IRiseToken
    function sell(uint256 _shares, address _recipient, uint256 _amountOutMin) external payable {
        SellParams memory params = SellParams({
            seller: msg.sender,
            recipient: _recipient,
            tokenOut: IERC20(address(0)),
            amountOutMin: _amountOutMin,
            shares: _shares,
            collateralAmount: 0,
            debtAmount: 0,
            fee: 0,
            nav: nav()
        });
        sell(params);
    }

    /// @inheritdoc IRiseToken
    function sell(uint256 _shares, address _recipient, address _tokenOut, uint256 _amountOutMin) external {
        SellParams memory params = SellParams({
            seller: msg.sender,
            recipient: _recipient,
            tokenOut: IERC20(_tokenOut),
            amountOutMin: _amountOutMin,
            shares: _shares,
            collateralAmount: 0,
            debtAmount: 0,
            fee: 0,
            nav: nav()
        });
        sell(params);
    }

    receive() external payable {}
}
