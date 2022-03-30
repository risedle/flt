// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { UniswapAdapter } from "../adapters/UniswapAdapter.sol";
import { RariFusePriceOracleAdapter } from "../adapters/RariFusePriceOracleAdapter.sol";
import { RiseTokenFactory } from "../RiseTokenFactory.sol";
import { RiseToken } from "../RiseToken.sol";

import { IRiseToken } from "../interfaces/IRiseToken.sol";
import { IUniswapAdapter } from "../interfaces/IUniswapAdapter.sol";
import { IfERC20 } from "../interfaces/IfERC20.sol";
import { HEVM } from "./hevm/HEVM.sol";
import { weth, usdc, wbtc, gohm } from "chain/Tokens.sol";
import { fusdc, fwbtc } from "chain/Tokens.sol";
import { rariFuseUSDCPriceOracle, rariFuseWBTCPriceOracle } from "chain/Tokens.sol";
import { uniswapV3USDCETHPool, uniswapV3Router, uniswapV3WBTCETHPool } from "chain/Tokens.sol";

/**
 * @title Rise Token Test User
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract User {
    using SafeERC20 for IERC20;

    RiseToken private riseToken;

    constructor(RiseToken _riseToken) {
        riseToken = _riseToken;
    }

    function buy(uint256 _shares) public payable {
        riseToken.buy{value: msg.value}(_shares, address(this), address(0), msg.value);
    }

    function buy(uint256 _shares, address _recipient) public payable {
        riseToken.buy{value: msg.value}(_shares, _recipient, address(0), msg.value);
    }

    function buy(uint256 _shares, address _tokenIn, uint256 _amountInMax) public {
        IERC20(_tokenIn).safeIncreaseAllowance(address(riseToken), _amountInMax);
        riseToken.buy(_shares, address(this), _tokenIn, _amountInMax);
    }

    function buy(uint256 _shares, address _recipient, address _tokenIn, uint256 _amountInMax) public {
        IERC20(_tokenIn).safeIncreaseAllowance(address(riseToken), _amountInMax);
        riseToken.buy(_shares, _recipient, _tokenIn, _amountInMax);
    }

    function sell(uint256 _shares, uint256 _amountOutMin) public {
        IERC20(address(riseToken)).safeIncreaseAllowance(address(riseToken), _shares);
        riseToken.sell(_shares, address(this), address(0), _amountOutMin);
    }

    function sell(uint256 _shares, uint256 _amountOutMin, address _recipient) public {
        IERC20(address(riseToken)).safeIncreaseAllowance(address(riseToken), _shares);
        riseToken.sell(_shares, _recipient, address(0), _amountOutMin);
    }

    function sell(uint256 _shares, address _tokenOut, uint256 _amountOutMin) public {
        IERC20(address(riseToken)).safeIncreaseAllowance(address(riseToken), _shares);
        riseToken.sell(_shares, address(this), _tokenOut, _amountOutMin);
    }

    function sell(uint256 _shares, address _tokenOut, uint256 _amountOutMin, address _recipient) public {
        IERC20(address(riseToken)).safeIncreaseAllowance(address(riseToken), _shares);
        riseToken.sell(_shares, _recipient, _tokenOut, _amountOutMin);
    }

    receive() external payable {}
}

/**
 * @title Rise Token Market Marker
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract MarketMaker {
    using SafeERC20 for ERC20;

    RiseToken private riseToken;

    constructor(RiseToken _riseToken) {
        riseToken = _riseToken;
    }

    receive() external payable {}

    function sell(uint256 _collateralAmount, uint256 _amountOutMin) public returns (uint256 _amountOut) {
        riseToken.collateral().safeIncreaseAllowance(address(riseToken), _collateralAmount);
        _amountOut = riseToken.swapExactCollateralForETH(_collateralAmount, _amountOutMin);
    }

    function buy(uint256 _ethAmount, uint256 _amountOutMin) public payable returns (uint256 _amountOut) {
        _amountOut = riseToken.swapExactETHForCollateral{value: _ethAmount}(_amountOutMin);
    }

}

/**
 * @title Rise Token Test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract RiseTokenTest is DSTest {
    using SafeERC20 for IERC20;
    HEVM private hevm;
    UniswapAdapter private uniswapAdapterCached;
    RariFusePriceOracleAdapter private oracleAdapterCached;
    RiseToken private wbtcRiseCached;
    address private feeRecipient;

    function getInitializeParams(
        uint256 _totalCollateralMin,
        uint256 _nav,
        uint256 _lr,
        uint256 _cdecimals,
        RiseToken riseToken
    ) internal view returns (IRiseToken.InitializeParams memory _params) {
        // Get the initial total shares using 2x leverage ratio
        uint256 price = oracleAdapterCached.price(address(riseToken.collateral()), address(riseToken.debt()));
        uint256 targetCollateralAmount = 2 * _totalCollateralMin;
        uint256 targetBorrowAmount = (_totalCollateralMin * price) / (10**_cdecimals);
        uint256 targetCollateralValue = (targetCollateralAmount * price) / (10**_cdecimals);
        uint256 totalValue = targetCollateralValue - targetBorrowAmount;
        uint256 totalShares = (totalValue * (10**_cdecimals)) / _nav;

        /// If target leverage ratio less than 2x, then Leverage down
        uint256 delta;
        uint256 repayAmount;
        uint256 borrowAmount;

        if (_lr < 2 ether) {
            delta = 2 ether - _lr;
            repayAmount = ((delta * totalShares) / 1e18) * _nav / (10**_cdecimals);
            uint256 collateralSold = (repayAmount * (10**_cdecimals)) / price;
            targetBorrowAmount -= repayAmount;
            targetCollateralAmount -= collateralSold;
        }

        /// If target leverage ratio larger than 2x, then Leverage up
        if (_lr > 2 ether) {
            delta = _lr - 2 ether;
            borrowAmount = ((delta * totalShares) / 1e18) * _nav / (10**_cdecimals);
            uint256 collateralBought = (borrowAmount * (10**_cdecimals)) / price;
            targetBorrowAmount += borrowAmount;
            targetCollateralAmount += collateralBought;
        }

        // Create the parameters
        _params = IRiseToken.InitializeParams({
            borrowAmount: targetBorrowAmount,
            collateralAmount: targetCollateralAmount,
            initializer: address(this),
            shares: totalShares,
            leverageRatio: _lr,
            nav: _nav,
            ethAmount: getETHAmount(riseToken, targetCollateralAmount, targetBorrowAmount)
        });
    }

    function getETHAmount(RiseToken riseToken, uint256 targetCollateralAmount, uint256 targetBorrowAmount) internal view returns (uint256) {
        // Get the price in ETH
        uint256 cPrice = oracleAdapterCached.price(address(riseToken.collateral()));
        uint256 dPrice = oracleAdapterCached.price(address(riseToken.debt()));

        // Get total value in ETH
        uint256 collateralValue = (targetCollateralAmount * cPrice) / (10**8); // WBTC 8 decimals
        uint256 borrowValue = (targetBorrowAmount * dPrice) / (10**6); // USDC 6 decimals

        // Get the estimated ETH
        return collateralValue - borrowValue;
    }

    function setUp() public {
        hevm = new HEVM();

        // Set fee recipient
        feeRecipient = hevm.addr(333);

        // Add supply to the Rari Fuse
        uint256 supplyAmount = 100_000_000 * 1e6; // 100K USDC
        hevm.setUSDCBalance(address(this), supplyAmount);
        IERC20(usdc).safeIncreaseAllowance(fusdc, supplyAmount);
        IfERC20(fusdc).mint(supplyAmount);

        // Create new factory
        uniswapAdapterCached = new UniswapAdapter(weth);
        uniswapAdapterCached.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV3, uniswapV3WBTCETHPool, uniswapV3Router);
        uniswapAdapterCached.configure(usdc, IUniswapAdapter.UniswapVersion.UniswapV3, uniswapV3USDCETHPool, uniswapV3Router);

        oracleAdapterCached = new RariFusePriceOracleAdapter();
        oracleAdapterCached.configure(wbtc, rariFuseWBTCPriceOracle);
        oracleAdapterCached.configure(usdc, rariFuseUSDCPriceOracle);

        // Create factory
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new Rise token
        wbtcRiseCached = RiseToken(payable(factory.create(fwbtc, fusdc, address(uniswapAdapterCached), address(oracleAdapterCached))));

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.08 * 1e8; //
        uint256 leverageRatio = 2 * 1e18;

        // Slippage tolerance 3%
        IRiseToken.InitializeParams memory params = getInitializeParams(collateralAmount, nav, leverageRatio, 8, wbtcRiseCached); // 8 decimals for WBTC
        params.ethAmount += (0.3 ether * params.ethAmount) / 1 ether;
        wbtcRiseCached.initialize{value: params.ethAmount}(params);

    }

    function initializeWithCustomLeverageRatio(uint256 _lr) internal returns (RiseToken _wbtcRise) {
        // Create factory
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new Rise token
        _wbtcRise = RiseToken(payable(factory.create(fwbtc, fusdc, address(uniswapAdapterCached), address(oracleAdapterCached))));

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8;

        IRiseToken.InitializeParams memory params = getInitializeParams(collateralAmount, nav, _lr, 8, _wbtcRise); // 8 decimals for WBTC
        params.ethAmount += (0.5 ether * params.ethAmount) / 1 ether;
        _wbtcRise.initialize{value: params.ethAmount}(params);
    }

    function previewBuy(RiseToken _riseToken, uint256 _shares) public view returns (uint256 _ethAmount) {
        if (_shares == 0) return 0;
        uint256 fee = ((_riseToken.fees() * _shares) / 1e18);
        uint256 newShares = _shares + fee;
        _ethAmount = _riseToken.value(newShares);
    }

    function previewBuy(RiseToken _riseToken, uint256 _shares, address _tokenIn) public view returns (uint256 _amountIn) {
        if (_shares == 0) return 0;
        uint256 fee = ((_riseToken.fees() * _shares) / 1e18);
        uint256 newShares = _shares + fee;
        _amountIn = _riseToken.value(newShares, _tokenIn);
    }

    function previewSell(RiseToken _riseToken, uint256 _shares) public view returns (uint256 _ethAmount) {
        if (_shares == 0) return 0;
        uint256 fee = ((_riseToken.fees() * _shares) / 1e18);
        uint256 newShares = _shares - fee;
        _ethAmount = _riseToken.value(newShares);
    }

    function previewSell(RiseToken _riseToken, uint256 _shares, address _tokenOut) public view returns (uint256 _amountOut) {
        if (_shares == 0) return 0;
        uint256 fee = ((_riseToken.fees() * _shares) / 1e18);
        uint256 newShares = _shares - fee;
        _amountOut = _riseToken.value(newShares, _tokenOut);
    }

    function wtb(RiseToken riseToken) public view returns (uint256 _amount) {
        uint256 decimals = riseToken.collateral().decimals();
        uint256 oneShare = (10**decimals);
        _amount = ((riseToken.step() * riseToken.value(oneShare, address(riseToken.collateral())) / 1e18) * riseToken.totalSupply()) / oneShare;
    }

    function wts(RiseToken riseToken) public view returns (uint256 _amount) {
        uint256 decimals = riseToken.collateral().decimals();
        uint256 oneShare = (10**decimals);
        _amount = ((riseToken.step() * riseToken.value(oneShare, address(riseToken.collateral())) * riseToken.totalSupply())) / oneShare;
    }


    function testFailInitializeWBTCRISERevertIfSlippageTooHigh() public {
        // Create factory
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new Rise token
        RiseToken wbtcRise = RiseToken(payable(factory.create(fwbtc, fusdc, address(uniswapAdapterCached), address(oracleAdapterCached))));

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.08 * 1e8;
        uint256 leverageRatio = 2 * 1e18;

        // Assume Real ETH price is -5% so we can test the slippgae
        IRiseToken.InitializeParams memory params = getInitializeParams(collateralAmount, nav, leverageRatio, 8, wbtcRise); // 8 decimals for WBTC
        params.ethAmount -= (0.5 ether * params.ethAmount) / 1 ether;
        wbtcRise.initialize{value: params.ethAmount}(params);
    }

    function testInitializeWBTCRISEWithLeverageRatio2x() public {
        // Create factory
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new Rise token
        RiseToken wbtcRise = RiseToken(payable(factory.create(fwbtc, fusdc, address(uniswapAdapterCached), address(oracleAdapterCached))));

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.08 * 1e8; //
        uint256 leverageRatio = 2*1e18;

        // Slippage tolerance 3%
        IRiseToken.InitializeParams memory params = getInitializeParams(collateralAmount, nav, leverageRatio, 8, wbtcRise); // 8 decimals for WBTC
        params.ethAmount += (0.3 ether * params.ethAmount) / 1 ether;
        wbtcRise.initialize{value: params.ethAmount}(params);

        // Check the parameters
        assertTrue(wbtcRise.isInitialized());
        assertEq(wbtcRise.totalCollateral(), 2 * collateralAmount, "check total collateral");

        uint256 debt = (collateralAmount * oracleAdapterCached.price(wbtc, usdc)) / 1e8;
        assertEq(wbtcRise.totalDebt(), debt, "check total debt");

        assertGt(wbtcRise.totalSupply(), 0, "check rise token supply");
        assertEq(wbtcRise.totalSupply(), wbtcRise.balanceOf(address(this)), "check rise token supply");

        assertGt(wbtcRise.value(1e8, usdc), nav - 1e6, "check nav");
        assertLt(wbtcRise.value(1e8, usdc), nav + 1e6, "check nav");
        assertGt(wbtcRise.leverageRatio(), leverageRatio - 0.001 ether, "check leverage ratio");
        assertLt(wbtcRise.leverageRatio(), leverageRatio + 0.001 ether, "check leverage ratio");
    }

    function testInitializeWBTCRISEWithLeverageRatio1point69x() public {
        // Create factory
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new Rise token
        RiseToken wbtcRise = RiseToken(payable(factory.create(fwbtc, fusdc, address(uniswapAdapterCached), address(oracleAdapterCached))));

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.9 * 1e8; // This might be change in the future, min borrow on mainnet is 1ETH
        uint256 leverageRatio = 1.69 * 1e18;

        // Slippage tolerance 3%
        IRiseToken.InitializeParams memory params = getInitializeParams(collateralAmount, nav, leverageRatio, 8, wbtcRise); // 8 decimals for WBTC
        params.ethAmount += (0.3 ether * params.ethAmount) / 1 ether;
        wbtcRise.initialize{value: params.ethAmount}(params);

        // Check the parameters
        assertTrue(wbtcRise.isInitialized());

        assertGt(wbtcRise.totalSupply(), 0, "check rise token supply");
        assertEq(wbtcRise.totalSupply(), wbtcRise.balanceOf(address(this)), "check rise token supply");

        assertGt(wbtcRise.value(1e8, usdc), nav - 1e6, "check nav");
        assertLt(wbtcRise.value(1e8, usdc), nav + 1e6, "check nav");
        assertGt(wbtcRise.leverageRatio(), leverageRatio - 0.001 ether, "check leverage ratio");
        assertLt(wbtcRise.leverageRatio(), leverageRatio + 0.001 ether, "check leverage ratio");
    }

    function testInitializeWBTCRISEWithLeverageRatio2point5x() public {
        // Create factory
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new Rise token
        RiseToken wbtcRise = RiseToken(payable(factory.create(fwbtc, fusdc, address(uniswapAdapterCached), address(oracleAdapterCached))));

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.08 * 1e8; //
        uint256 leverageRatio = 2.5 * 1e18;

        // Slippage tolerance 3%
        IRiseToken.InitializeParams memory params = getInitializeParams(collateralAmount, nav, leverageRatio, 8, wbtcRise); // 8 decimals for WBTC
        params.ethAmount += (0.3 ether * params.ethAmount) / 1 ether;
        wbtcRise.initialize{value: params.ethAmount}(params);

        // Check the parameters
        assertTrue(wbtcRise.isInitialized());

        assertGt(wbtcRise.totalSupply(), 0, "check rise token supply");
        assertEq(wbtcRise.totalSupply(), wbtcRise.balanceOf(address(this)), "check rise token supply");

        assertGt(wbtcRise.value(1e8, usdc), nav - 1e6, "check nav");
        assertLt(wbtcRise.value(1e8, usdc), nav + 1e6, "check nav");
        assertGt(wbtcRise.leverageRatio(), leverageRatio - 0.001 ether, "check leverage ratio");
        assertLt(wbtcRise.leverageRatio(), leverageRatio + 0.001 ether, "check leverage ratio");
    }

    function testInitializeWBTCRISERefundExcessETH() public {
        // Create factory
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new Rise token
        RiseToken wbtcRise = RiseToken(payable(factory.create(fwbtc, fusdc, address(uniswapAdapterCached), address(oracleAdapterCached))));

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.08 * 1e8; //
        uint256 leverageRatio = 2 * 1e18;

        uint256 prevBalance = address(this).balance;
        IRiseToken.InitializeParams memory params = getInitializeParams(collateralAmount, nav, leverageRatio, 8, wbtcRise); // 8 decimals for WBTC
        params.ethAmount += (2 * params.ethAmount);
        wbtcRise.initialize{value: params.ethAmount}(params);

        // Check the parameters
        assertTrue(wbtcRise.isInitialized());
        assertEq(wbtcRise.totalCollateral(), 2 * collateralAmount, "check total collateral");

        uint256 debt = (collateralAmount * oracleAdapterCached.price(wbtc, usdc)) / 1e8;
        assertEq(wbtcRise.totalDebt(), debt, "check total debt");

        assertGt(wbtcRise.totalSupply(), 0, "check rise token supply");
        assertEq(wbtcRise.totalSupply(), wbtcRise.balanceOf(address(this)), "check rise token supply");

        assertGt(wbtcRise.value(1e8, usdc), nav - 1e6, "check nav");
        assertLt(wbtcRise.value(1e8, usdc), nav + 1e6, "check nav");
        assertGt(wbtcRise.leverageRatio(), leverageRatio - 0.001 ether, "check leverage ratio");
        assertLt(wbtcRise.leverageRatio(), leverageRatio + 0.001 ether, "check leverage ratio");

        // Make sure ETH is refunded
        assertGt(address(this).balance, prevBalance - params.ethAmount, "check excess ETH refund");
    }

    function testFailBuyRevertIfRiseTokenNotInitialized() public {
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);
        RiseToken wbtcRise = RiseToken(payable(factory.create(fwbtc, fusdc, address(uniswapAdapterCached), address(oracleAdapterCached))));
        uint256 shares = 0.1 * 1e8;
        uint256 ethAmount = previewBuy(wbtcRise, shares);
        ethAmount += (0.03 ether * ethAmount) / 1 ether; // slippage 3%
        wbtcRise.buy{value: ethAmount}(shares, address(this), address(0), ethAmount);
    }

    function testFailBuyRevertIfMoreThanMaxBuy() public {
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);
        RiseToken wbtcRise = RiseToken(payable(factory.create(fwbtc, fusdc, address(uniswapAdapterCached), address(oracleAdapterCached))));
        wbtcRise.setParams(wbtcRise.minLeverageRatio(), wbtcRise.maxLeverageRatio(), wbtcRise.step(), wbtcRise.discount(), 2 * 1e8);

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.08 * 1e8; //
        uint256 leverageRatio = 2 * 1e18;

        // Slippage tolerance 3%
        IRiseToken.InitializeParams memory params = getInitializeParams(collateralAmount, nav, leverageRatio, 8, wbtcRise); // 8 decimals for WBTC
        params.ethAmount += (0.3 ether * params.ethAmount) / 1 ether;
        wbtcRise.initialize{value: params.ethAmount}(params);

        uint256 shares = 10 * 1e8;
        uint256 ethAmount = previewBuy(wbtcRise, shares);
        ethAmount += (0.03 ether * ethAmount) / 1 ether; // slippage 3%
        wbtcRise.buy{value: ethAmount}(shares, address(this), address(0), ethAmount);
    }

    function testFailBuyWithETHRevertIfSlippageIsTooHigh() public {
        uint256 shares = 0.1 * 1e8;
        uint256 ethAmount = previewBuy(wbtcRiseCached, shares);
        ethAmount -= (0.05 ether * ethAmount) / 1 ether; // slippage -5% to test out the revert
        wbtcRiseCached.buy{value: ethAmount}(shares, address(this), address(0), ethAmount);
    }

    function testFailBuyWithUSDCRevertIfSlippageIsTooHigh() public {
        uint256 shares = 0.1 * 1e8;
        uint256 usdcAmount = previewBuy(wbtcRiseCached, shares, usdc);
        usdcAmount -= (0.05 ether * usdcAmount) / 1 ether; // slippage -5% to test out the revert

        // Top up user balance
        hevm.setUSDCBalance(address(this), usdcAmount);
        IERC20(usdc).safeIncreaseAllowance(address(wbtcRiseCached), usdcAmount);
        wbtcRiseCached.buy(shares, address(this), usdc, usdcAmount);
    }

    function testBuyWBTCRISEWithETH() public {
        uint256 shares = 0.1 * 1e8;
        uint256 ethAmountInMax = previewBuy(wbtcRiseCached, shares);
        ethAmountInMax += (0.05 ether * ethAmountInMax) / 1 ether; // Slippage tollerance 3%

        // Make sure these are value doesn't not change
        uint256 cps = wbtcRiseCached.collateralPerShare();
        uint256 dps = wbtcRiseCached.debtPerShare();
        uint256 navInETH  = wbtcRiseCached.nav();
        uint256 navInUSDC = wbtcRiseCached.value(1e8, usdc);
        uint256 lr  = wbtcRiseCached.leverageRatio();

        uint256 prevTotalSupply = wbtcRiseCached.totalSupply();
        uint256 prevFeeBalance = wbtcRiseCached.balanceOf(feeRecipient);

        // Create new user
        User user = new User(wbtcRiseCached);

        // User buy the token
        user.buy{value: ethAmountInMax}(shares);
        uint256 totalFees = (0.001 ether * shares) / 1 ether;

        // Make sure the seller receives the token
        assertEq(wbtcRiseCached.balanceOf(address(user)), shares, "check buyer balance");
        assertEq(wbtcRiseCached.totalSupply(), prevTotalSupply + shares + totalFees, "check total supply");

        // Make sure the fee recipient receives the fees from buy
        assertEq(wbtcRiseCached.balanceOf(feeRecipient), prevFeeBalance + (0.001 ether * shares) / 1 ether, "check fee recipient balance");

        // Make sure these values doesn't change after buy
        assertEq(wbtcRiseCached.collateralPerShare(), cps, "check cps");
        assertEq(wbtcRiseCached.debtPerShare(), dps, "check dps");
        assertEq(wbtcRiseCached.nav(), navInETH, "check nav in ETH");
        assertEq(wbtcRiseCached.value(1e8, usdc), navInUSDC, "check nav in USDC");
        assertEq(wbtcRiseCached.leverageRatio(), lr, "check leverage ratio");
    }

    function testBuyWBTCRISEWithETHExcessRefunded() public {
        uint256 shares = 0.1 * 1e8;
        uint256 ethAmountInMax = previewBuy(wbtcRiseCached, shares);
        ethAmountInMax += (0.5 ether * ethAmountInMax) / 1 ether; // Slippage tollerance 50%

        // Create new user
        User user = new User(wbtcRiseCached);

        // User buy the token
        user.buy{value: ethAmountInMax}(shares);

        // Make sure the ETH is refunded
        assertGt(address(user).balance, 0);
    }

    function testBuyWBTCRISEWithETHAndCustomRecipient() public {
        uint256 shares = 0.1 * 1e8;
        uint256 ethAmountInMax = previewBuy(wbtcRiseCached, shares);
        ethAmountInMax += (0.5 ether * ethAmountInMax) / 1 ether; // Slippage tollerance 50%

        // Create new user
        User user = new User(wbtcRiseCached);

        // User buy the token
        address recipient = hevm.addr(34);
        user.buy{value: ethAmountInMax}(shares, recipient);

        // Make sure the recipient receives the shares
        assertEq(wbtcRiseCached.balanceOf(recipient), shares);
    }

    function testBuyWBTCRISEWithUSDC() public {
        uint256 shares = 0.1 * 1e8;
        uint256 usdcAmountInMax = previewBuy(wbtcRiseCached, shares, usdc);
        usdcAmountInMax += (0.05 ether * usdcAmountInMax) / 1 ether; // Slippage tollerance 5%

        // Make sure these are value doesn't not change
        uint256 cps = wbtcRiseCached.collateralPerShare();
        uint256 dps = wbtcRiseCached.debtPerShare();
        uint256 navInETH  = wbtcRiseCached.nav();
        uint256 navInUSDC = wbtcRiseCached.value(1e8, usdc);
        uint256 lr  = wbtcRiseCached.leverageRatio();

        uint256 prevTotalSupply = wbtcRiseCached.totalSupply();
        uint256 prevFeeBalance = wbtcRiseCached.balanceOf(feeRecipient);

        // Create new user
        User user = new User(wbtcRiseCached);

        // User buy the token
        hevm.setUSDCBalance(address(user), usdcAmountInMax);
        user.buy(shares, usdc, usdcAmountInMax);
        uint256 totalFees = (0.001 ether * shares) / 1 ether;

        // Make sure the buyer receives the token
        assertEq(wbtcRiseCached.balanceOf(address(user)), shares, "check buyer balance");
        assertEq(wbtcRiseCached.totalSupply(), prevTotalSupply + shares + totalFees, "check total supply");

        // Make sure the buyer is debitted
        assertLt(IERC20(usdc).balanceOf(address(user)), usdcAmountInMax);

        // Make sure the fee recipient receives the fees from buy
        assertEq(wbtcRiseCached.balanceOf(feeRecipient), prevFeeBalance + totalFees, "check fee recipient balance");

        // Make sure these values doesn't change after buy
        assertEq(wbtcRiseCached.collateralPerShare(), cps, "check cps");
        assertEq(wbtcRiseCached.debtPerShare(), dps, "check dps");
        assertEq(wbtcRiseCached.nav(), navInETH, "check nav in ETH");
        assertEq(wbtcRiseCached.value(1e8, usdc), navInUSDC, "check nav in USDC");
        assertEq(wbtcRiseCached.leverageRatio(), lr, "check leverage ratio");
    }

    function testBuyWBTCRISEWithUSDCExcessRefunded() public {
        uint256 shares = 0.1 * 1e8;
        uint256 usdcAmountInMax = previewBuy(wbtcRiseCached, shares, usdc);
        usdcAmountInMax += (0.5 ether * usdcAmountInMax) / 1 ether; // Slippage tollerance 3%

        // Create new user
        User user = new User(wbtcRiseCached);

        // User buy the token
        hevm.setUSDCBalance(address(user), usdcAmountInMax);
        user.buy(shares, usdc, usdcAmountInMax);

        // Make sure the buyer USDC is refunded
        assertGt(IERC20(usdc).balanceOf(address(user)), 0, "check usdc balance");
    }

    function testBuyWBTCRISEWithUSDCAndCustomRecipient() public {
        uint256 shares = 0.1 * 1e8;
        uint256 usdcAmountInMax = previewBuy(wbtcRiseCached, shares, usdc);
        usdcAmountInMax += (0.5 ether * usdcAmountInMax) / 1 ether; // Slippage tollerance 3%

        // Create new user
        User user = new User(wbtcRiseCached);

        // User buy the token
        hevm.setUSDCBalance(address(user), usdcAmountInMax);
        address recipient = hevm.addr(39);
        user.buy(shares, recipient, usdc, usdcAmountInMax);

        // Make sure the recipient recieves the token
        assertGt(wbtcRiseCached.balanceOf(recipient), 0, "check usdc balance");
    }

    function testFailSellWBTCRevertIfRiseTokenNotInitialized() public {
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);
        RiseToken wbtcRise = RiseToken(payable(factory.create(fwbtc, fusdc, address(uniswapAdapterCached), address(oracleAdapterCached))));
        uint256 shares = 0.1 * 1e8;
        uint256 ethAmountOutMin = previewSell(wbtcRise, shares);
        ethAmountOutMin -= (0.03 ether * ethAmountOutMin) / 1 ether; // slippage tollerance 3%
        wbtcRise.sell(shares, address(this), address(0), ethAmountOutMin);
    }

    function testFailSellWBTCForETHRevertIfSlippageIsTooHigh() public {
        uint256 shares = 0.1 * 1e8;
        uint256 ethAmountInMax = previewBuy(wbtcRiseCached, shares);
        ethAmountInMax += (0.03 ether * ethAmountInMax) / 1 ether; // Slippage tollerance 3%
        uint256 ethAmountOutMin = previewSell(wbtcRiseCached, shares);
        ethAmountOutMin += (0.05 ether * ethAmountOutMin) / 1 ether; // slippage -5% to test out the revert

        // Create new user
        User user = new User(wbtcRiseCached);

        // User buy the token
        user.buy{value: ethAmountInMax}(shares);

        // User sell the token with high slippage
        user.sell(shares, ethAmountOutMin);
    }

    function testFailSellWBTCForUSDCRevertIfSlippageIsTooHigh() public {
        uint256 shares = 0.1 * 1e8;
        uint256 usdcAmountInMax = previewBuy(wbtcRiseCached, shares, usdc);
        usdcAmountInMax += (0.05 ether * usdcAmountInMax) / 1 ether; // Slippage tollerance 3%
        uint256 usdcAmountOutMin = previewSell(wbtcRiseCached, shares, usdc);
        usdcAmountOutMin += (0.05 ether * usdcAmountOutMin) / 1 ether; // slippage -5% to test out the revert

        // Create new user
        User user = new User(wbtcRiseCached);

        // Topup user balance
        hevm.setUSDCBalance(address(user), usdcAmountInMax);

        // User buy the token
        user.buy(shares, usdc, usdcAmountInMax);

        // User sell the token with high slippage
        user.sell(shares, usdc, usdcAmountOutMin);

    }

    function testSellWBTCRISEForETH() public {
        uint256 shares = 0.1 * 1e8;
        uint256 ethAmountInMax = previewBuy(wbtcRiseCached, shares);
        ethAmountInMax += (0.05 ether * ethAmountInMax) / 1 ether; // Slippage tollerance 5%
        uint256 ethAmountOutMin = previewSell(wbtcRiseCached, shares);
        ethAmountOutMin -= (0.03 ether * ethAmountOutMin) / 1 ether; // Slippage tollerance 3%

        // Make sure these are value doesn't not change
        uint256 cps = wbtcRiseCached.collateralPerShare();
        uint256 dps = wbtcRiseCached.debtPerShare();
        uint256 navInETH  = wbtcRiseCached.nav();
        uint256 navInUSDC = wbtcRiseCached.value(1e8, usdc);
        uint256 lr  = wbtcRiseCached.leverageRatio();

        uint256 prevTotalSupply = wbtcRiseCached.totalSupply();
        uint256 prevFeeBalance = wbtcRiseCached.balanceOf(feeRecipient);

        // Create new user
        User user = new User(wbtcRiseCached);

        // User buy the token
        user.buy{value: ethAmountInMax}(shares);
        assertGt(wbtcRiseCached.balanceOf(feeRecipient), prevFeeBalance, "check fee recipient balance after buy");

        // User sell the token for ETH
        user.sell(shares, ethAmountOutMin);
        assertGt(wbtcRiseCached.balanceOf(feeRecipient), prevFeeBalance, "check fee recipient balance after sell");

        // Make sure the seller token is burned
        uint256 totalFees = ((0.001 ether * shares) / 1 ether) * 2;
        assertEq(wbtcRiseCached.balanceOf(address(user)), 0, "check seller balance");
        assertEq(wbtcRiseCached.totalSupply(), prevTotalSupply + totalFees, "check total supply");

        // Make sure the seller receives the ETH
        assertGt(address(user).balance, ethAmountOutMin);

        // Make sure the fee recipient receives the fees from buy & sell
        assertGt(wbtcRiseCached.balanceOf(feeRecipient), prevFeeBalance, "check fee recipient balance true");
        assertEq(wbtcRiseCached.balanceOf(feeRecipient), prevFeeBalance + totalFees, "check fee recipient balance failed");

        // Make sure these values doesn't change after buy & sell
        assertEq(wbtcRiseCached.collateralPerShare(), cps, "check cps");
        assertEq(wbtcRiseCached.debtPerShare(), dps, "check dps");
        assertEq(wbtcRiseCached.nav(), navInETH, "check nav in ETH");
        assertEq(wbtcRiseCached.value(1e8, usdc), navInUSDC, "check nav in USDC");
        assertEq(wbtcRiseCached.leverageRatio(), lr, "check leverage ratio");
    }

    function testSellWBTCRISEForETHWithCustomRecipient() public {
        uint256 shares = 0.1 * 1e8;
        uint256 ethAmountInMax = previewBuy(wbtcRiseCached, shares);
        ethAmountInMax += (0.05 ether * ethAmountInMax) / 1 ether; // Slippage tollerance 5%
        uint256 ethAmountOutMin = previewSell(wbtcRiseCached, shares);
        ethAmountOutMin -= (0.03 ether * ethAmountOutMin) / 1 ether; // Slippage tollerance 3%

        // Create new user
        User user = new User(wbtcRiseCached);

        // User buy the token
        user.buy{value: ethAmountInMax}(shares);

        // User sell the token for ETH with custom recipient
        address recipient = hevm.addr(3);
        user.sell(shares, ethAmountOutMin, recipient);

        // Make sure the recipient receives the ETH
        assertGt(recipient.balance, ethAmountOutMin);
    }

    function testSellWBTCRISEForUSDC() public {
        uint256 shares = 0.1 * 1e8;
        uint256 usdcAmountInMax = previewBuy(wbtcRiseCached, shares, usdc);
        usdcAmountInMax += (0.05 ether * usdcAmountInMax) / 1 ether; // Slippage tollerance 5%
        uint256 usdcAmountOutMin = previewSell(wbtcRiseCached, shares, usdc);
        usdcAmountOutMin -= (0.03 ether * usdcAmountOutMin) / 1 ether; // Slippage tollerance 3%

        // Make sure these are value doesn't not change
        uint256 cps = wbtcRiseCached.collateralPerShare();
        uint256 dps = wbtcRiseCached.debtPerShare();
        uint256 navInETH  = wbtcRiseCached.nav();
        uint256 navInUSDC = wbtcRiseCached.value(1e8, usdc);
        uint256 lr  = wbtcRiseCached.leverageRatio();

        uint256 prevTotalSupply = wbtcRiseCached.totalSupply();
        uint256 prevFeeBalance = wbtcRiseCached.balanceOf(feeRecipient);

        // Create new user
        User user = new User(wbtcRiseCached);

        // User buy the token
        hevm.setUSDCBalance(address(user), usdcAmountInMax);
        user.buy(shares, usdc, usdcAmountInMax);
        assertGt(wbtcRiseCached.balanceOf(feeRecipient), prevFeeBalance, "check fee recipient balance after buy");

        // User sell the token for USDC
        user.sell(shares, usdc, usdcAmountOutMin);
        assertGt(wbtcRiseCached.balanceOf(feeRecipient), prevFeeBalance, "check fee recipient balance after sell");

        // Make sure the seller token is burned
        uint256 totalFees = ((0.001 ether * shares) / 1 ether) * 2;
        assertEq(wbtcRiseCached.balanceOf(address(user)), 0, "check seller balance");
        assertEq(wbtcRiseCached.totalSupply(), prevTotalSupply + totalFees, "check total supply");

        // Make sure the seller receives the USDC
        assertGt(IERC20(usdc).balanceOf(address(user)), usdcAmountOutMin);

        // Make sure the fee recipient receives the fees from buy & sell
        assertEq(wbtcRiseCached.balanceOf(feeRecipient), prevFeeBalance + totalFees, "check fee recipient balance");

        // Make sure these values doesn't change after buy & sell
        assertEq(wbtcRiseCached.collateralPerShare(), cps, "check cps");
        assertEq(wbtcRiseCached.debtPerShare(), dps, "check dps");
        assertEq(wbtcRiseCached.nav(), navInETH, "check nav in ETH");
        assertEq(wbtcRiseCached.value(1e8, usdc), navInUSDC, "check nav in USDC");
        assertEq(wbtcRiseCached.leverageRatio(), lr, "check leverage ratio");
    }

    function testSellForUSDCWithCustomRecipient() public {
        uint256 shares = 0.1 * 1e8;
        uint256 usdcAmountInMax = previewBuy(wbtcRiseCached, shares, usdc);
        usdcAmountInMax += (0.05 ether * usdcAmountInMax) / 1 ether; // Slippage tollerance 3%
        uint256 usdcAmountOutMin = previewSell(wbtcRiseCached, shares, usdc);
        usdcAmountOutMin -= (0.03 ether * usdcAmountOutMin) / 1 ether; // Slippage tollerance 3%

        // Create new user
        User user = new User(wbtcRiseCached);

        // User buy the token
        hevm.setUSDCBalance(address(user), usdcAmountInMax);
        user.buy(shares, usdc, usdcAmountInMax);

        // User sell the token for USDC
        address recipient = hevm.addr(17);
        user.sell(shares, usdc, usdcAmountOutMin, recipient);

        // Make sure the recipient receives the ETH
        assertGt(IERC20(usdc).balanceOf(address(recipient)), usdcAmountOutMin);
    }

    function testSellWBTCRISEForWBTC() public {
        uint256 shares = 0.1 * 1e8;
        uint256 usdcAmountInMax = previewBuy(wbtcRiseCached, shares, usdc);
        usdcAmountInMax += (0.05 ether * usdcAmountInMax) / 1 ether; // Slippage tollerance 3%
        uint256 wbtcAmountOutMin = previewSell(wbtcRiseCached, shares, wbtc);
        wbtcAmountOutMin -= (0.03 ether * wbtcAmountOutMin) / 1 ether; // Slippage tollerance 3%

        // Make sure these are value doesn't not change
        uint256 cps = wbtcRiseCached.collateralPerShare();
        uint256 dps = wbtcRiseCached.debtPerShare();
        uint256 navInETH  = wbtcRiseCached.nav();
        uint256 navInUSDC = wbtcRiseCached.value(1e8, usdc);
        uint256 lr  = wbtcRiseCached.leverageRatio();

        uint256 prevTotalSupply = wbtcRiseCached.totalSupply();
        uint256 prevFeeBalance = wbtcRiseCached.balanceOf(feeRecipient);

        // Create new user
        User user = new User(wbtcRiseCached);

        // User buy the token
        hevm.setUSDCBalance(address(user), usdcAmountInMax);
        user.buy(shares, usdc, usdcAmountInMax);
        assertGt(wbtcRiseCached.balanceOf(feeRecipient), prevFeeBalance, "check fee recipient balance after buy");

        // User sell the token for WBTC
        user.sell(shares, wbtc, wbtcAmountOutMin);
        assertGt(wbtcRiseCached.balanceOf(feeRecipient), prevFeeBalance, "check fee recipient balance after sell");

        // Make sure the seller token is burned
        uint256 totalFees = ((0.001 ether * shares) / 1 ether) * 2;
        assertEq(wbtcRiseCached.balanceOf(address(user)), 0, "check seller balance");
        assertEq(wbtcRiseCached.totalSupply(), prevTotalSupply + totalFees, "check total supply");

        // Make sure the seller receives the WBTC
        assertGt(IERC20(wbtc).balanceOf(address(user)), wbtcAmountOutMin);

        // Make sure the fee recipient receives the fees from buy & sell
        assertEq(wbtcRiseCached.balanceOf(feeRecipient), prevFeeBalance + totalFees, "check fee recipient balance");

        // Make sure these values doesn't change after buy & sell
        assertEq(wbtcRiseCached.collateralPerShare(), cps, "check cps");
        assertEq(wbtcRiseCached.debtPerShare(), dps, "check dps");
        assertEq(wbtcRiseCached.nav(), navInETH, "check nav in ETH");
        assertEq(wbtcRiseCached.value(1e8, usdc), navInUSDC, "check nav in USDC");
        assertEq(wbtcRiseCached.leverageRatio(), lr, "check leverage ratio");
    }

    function testFailSwapExactCollateralForETHRevertIfLeverageRatioInRrange() public {
        wbtcRiseCached.swapExactCollateralForETH(1e8, 0);
    }

    function testFailSwapExactETHForCollateralRevertIfLeverageRatioInRrange() public {
        wbtcRiseCached.swapExactETHForCollateral(0);
    }

    function testFailSwapExactCollateralForETHRevertIfAmountInIsTooLarge() public {
        // Initialize Rise Token with 1.6x leverage ratio
        RiseToken wbtcRise = initializeWithCustomLeverageRatio(1.6 ether);
        wbtcRise.swapExactCollateralForETH(10*1e8, 0);
    }

    function testFailSwapExactETHForCollateralRevertIfAmountInIsTooLarge() public {
        // Initialize Rise Token with 2.4x leverage ratio
        RiseToken wbtcRise = initializeWithCustomLeverageRatio(2.4 ether);
        wbtcRise.swapExactETHForCollateral{value: 100 ether}(0.0001 * 1e8);
    }

    function testSwapExactCollateralForETHReturnZeroIfInputIsZero() public {
        RiseToken wbtcRise = initializeWithCustomLeverageRatio(1.6 ether);
        assertEq(wbtcRise.swapExactCollateralForETH(0, 0), 0);
    }

    function testSwapExactETHForCollateralReturnZeroIfInputIsZero() public {
        RiseToken wbtcRise = initializeWithCustomLeverageRatio(2.4 ether);
        assertEq(wbtcRise.swapExactETHForCollateral(0), 0);
    }

    function testSwapExactCollateralForETH() public {
        // Initialize Rise Token with 1.6x leverage ratio
        RiseToken wbtcRise = initializeWithCustomLeverageRatio(1.6 ether);

        // Create new market maker
        MarketMaker marketMaker = new MarketMaker(wbtcRise);
        assertEq(address(marketMaker).balance, 0, "check eth balance before swap");

        // Sell the collateral
        uint256 collateralAmount = wtb(wbtcRise);
        hevm.setWBTCBalance(address(marketMaker), collateralAmount);

        uint256 ethAmount = marketMaker.sell(collateralAmount, 0);

        assertEq(address(marketMaker).balance, ethAmount, "check eth balance after swap");
    }

    function testSwapExactETHForCollateral() public {
        // Initialize Rise Token with 2.4x leverage ratio
        RiseToken wbtcRise = initializeWithCustomLeverageRatio(2.4 ether);

        // Create new market maker
        MarketMaker marketMaker = new MarketMaker(wbtcRise);
        payable(address(marketMaker)).transfer(0.1 ether);

        assertEq(address(marketMaker).balance, 0.1 ether, "check eth balance before swap");

        // Sell the collateral
        uint256 collateralAmount = marketMaker.buy(0.1 ether, 0);

        // Get price
        uint256 price = oracleAdapterCached.price(wbtc);
        price -= (0.006 ether * price) / 1 ether;
        uint256 expectedCollateralAmount = (0.1 ether * 1e8) / price;

        assertEq(IERC20(wbtc).balanceOf(address(marketMaker)), collateralAmount, "check wbtc balance after swap");
        assertEq(address(marketMaker).balance, 0, "check eth balance after swap");
        assertEq(collateralAmount, expectedCollateralAmount, "check collateral amount");
    }

    function testFailSwapExactCollateralForETHRevertIfAmountOutMinTooLarge() public {
        // Initialize Rise Token with 1.6x leverage ratio
        RiseToken wbtcRise = initializeWithCustomLeverageRatio(1.6 ether);

        // Create new market maker
        MarketMaker marketMaker = new MarketMaker(wbtcRise);
        assertEq(address(marketMaker).balance, 0, "check eth balance before swap");

        // Sell the collateral
        uint256 collateralAmount = wtb(wbtcRise);
        hevm.setWBTCBalance(address(marketMaker), collateralAmount);

        marketMaker.sell(collateralAmount, 20 ether);
    }

    function testFailSwapExactETHForCollateralRevertIfAmountOutMinTooLarge() public {
        // Initialize Rise Token with 2.4x leverage ratio
        RiseToken wbtcRise = initializeWithCustomLeverageRatio(2.4 ether);

        // Create new market maker
        MarketMaker marketMaker = new MarketMaker(wbtcRise);
        payable(address(marketMaker)).transfer(0.1 ether);

        assertEq(address(marketMaker).balance, 0.1 ether, "check eth balance before swap");

        // Sell the collateral
        marketMaker.buy(0.1 ether, 2 * 1e8); // expect output 2 WBTC
    }

    receive() external payable {}
}
