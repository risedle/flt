// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { UniswapAdapter } from "../adapters/UniswapAdapter.sol";
import { RariFusePriceOracleAdapter } from "../adapters/RariFusePriceOracleAdapter.sol";
import { RiseTokenFactory } from "../RiseTokenFactory.sol";

import { IRiseToken } from "../interfaces/IRiseToken.sol";
import { IfERC20 } from "../interfaces/IfERC20.sol";

import { HEVM } from "./hevm/HEVM.sol";
import { weth, usdc, wbtc } from "chain/Tokens.sol";
import { fusdc, fwbtc } from "chain/Tokens.sol";
import { rariFuseUSDCPriceOracle, rariFuseWBTCPriceOracle } from "chain/Tokens.sol";
import { uniswapV3USDCETHPool, uniswapV3Router, uniswapV3WBTCETHPool } from "chain/Tokens.sol";

/**
 * @title Rise Token Test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract RiseTokenTest is DSTest {
    HEVM private hevm;
    UniswapAdapter private uniswapAdapterCached;
    RariFusePriceOracleAdapter private oracleAdapterCached;
    IRiseToken private wbtcRiseCached;
    address private feeRecipient;


    function setUp() public {
        hevm = new HEVM();

        // Set fee recipient
        feeRecipient = hevm.addr(333);

        // Add supply to the Rari Fuse
        uint256 supplyAmount = 100_000 * 1e6; // 100K USDC
        hevm.setUSDCBalance(address(this), supplyAmount);
        IERC20(usdc).approve(fusdc, supplyAmount);
        IfERC20(fusdc).mint(supplyAmount);

        // Create new factory
        uniswapAdapterCached = new UniswapAdapter(weth);
        uniswapAdapterCached.configure(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);
        uniswapAdapterCached.configure(usdc, 3, uniswapV3USDCETHPool, uniswapV3Router);

        oracleAdapterCached = new RariFusePriceOracleAdapter();
        oracleAdapterCached.configure(wbtc, rariFuseWBTCPriceOracle);
        oracleAdapterCached.configure(usdc, rariFuseUSDCPriceOracle);

        // Create factory
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient, address(uniswapAdapterCached), address(oracleAdapterCached));

        // Create new Rise token
        wbtcRiseCached = IRiseToken(factory.create(fwbtc, fusdc));

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.08 * 1e8; //
        uint256 leverageRatio = 2 * 1e18;
        uint256 ethAmount = wbtcRiseCached.previewInitialize(collateralAmount, nav, leverageRatio);

        // Slippage tolerance 3%
        ethAmount += (0.3 ether * ethAmount) / 1 ether;
        wbtcRiseCached.initialize{value: ethAmount}(collateralAmount, nav, leverageRatio);

    }

    function testFailPreviewInitializeRevertIfCollateralTokenIsNotConfiguredInOracleAdapter() public {
        // Create new factory
        UniswapAdapter uniswapAdapter = new UniswapAdapter(weth);
        uniswapAdapter.configure(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);
        uniswapAdapter.configure(usdc, 3, uniswapV3USDCETHPool, uniswapV3Router);

        RariFusePriceOracleAdapter oracleAdapter = new RariFusePriceOracleAdapter();
        // oracleAdapter.configure(wbtc, rariFuseWBTCPriceOracle);
        oracleAdapter.configure(usdc, rariFuseUSDCPriceOracle);

        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient, address(uniswapAdapter), address(oracleAdapter));

        // Create new Rise token
        IRiseToken wbtcRise = IRiseToken(factory.create(fwbtc, fusdc));

        // This should be reverted
        wbtcRise.previewInitialize(0.1 * 1e8, 400 * 1e6, 2*1e18);
    }

    function testFailPreviewInitializeRevertIfDebtTokenIsNotConfiguredInOracleAdapter() public {
        // Create new factory
        UniswapAdapter uniswapAdapter = new UniswapAdapter(weth);
        uniswapAdapter.configure(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);
        uniswapAdapter.configure(usdc, 3, uniswapV3USDCETHPool, uniswapV3Router);

        RariFusePriceOracleAdapter oracleAdapter = new RariFusePriceOracleAdapter();
        oracleAdapter.configure(wbtc, rariFuseWBTCPriceOracle);
        // oracleAdapter.configure(usdc, rariFuseUSDCPriceOracle);

        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient, address(uniswapAdapter), address(oracleAdapter));

        // Create new Rise token
        IRiseToken wbtcRise = IRiseToken(factory.create(fwbtc, fusdc));

        // This should be reverted
        wbtcRise.previewInitialize(0.1 * 1e8, 400 * 1e6, 2*1e18);
    }

    function testPreviewInitializeWBTCRISE() public {
        // Create new factory
        UniswapAdapter uniswapAdapter = new UniswapAdapter(weth);
        uniswapAdapter.configure(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);
        uniswapAdapter.configure(usdc, 3, uniswapV3USDCETHPool, uniswapV3Router);

        RariFusePriceOracleAdapter oracleAdapter = new RariFusePriceOracleAdapter();
        oracleAdapter.configure(wbtc, rariFuseWBTCPriceOracle);
        oracleAdapter.configure(usdc, rariFuseUSDCPriceOracle);

        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient, address(uniswapAdapter), address(oracleAdapter));

        // Create new Rise token
        IRiseToken wbtcRise = IRiseToken(factory.create(fwbtc, fusdc));

        // Initialize WBTCRISE with 400USDC nav, 0.01 BTC initial collateral and 2x leverage ratio
        uint256 ethAmount = wbtcRise.previewInitialize(0.01 * 1e8, 400 * 1e6, 2*1e18);
        assertLt(ethAmount, 1 ether);
    }

    function testFailInitializeWBTCRISERevertIfSlippageTooHigh() public {
        // Create factory
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient, address(uniswapAdapterCached), address(oracleAdapterCached));

        // Create new Rise token
        IRiseToken wbtcRise = IRiseToken(factory.create(fwbtc, fusdc));

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.08 * 1e8;
        uint256 leverageRatio = 2 * 1e18;
        uint256 ethAmount = wbtcRise.previewInitialize(collateralAmount, nav, leverageRatio);

        // Assume Real ETH price is -5% so we can test the slippgae
        ethAmount -= (0.5 ether * ethAmount) / 1 ether;
        wbtcRise.initialize{value: ethAmount}(collateralAmount, nav, leverageRatio); // This should be reverted to Slippage Too High
    }

    function testInitializeWBTCRISEWithLeverageRatio2x() public {
        // Create factory
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient, address(uniswapAdapterCached), address(oracleAdapterCached));

        // Create new Rise token
        IRiseToken wbtcRise = IRiseToken(factory.create(fwbtc, fusdc));

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.08 * 1e8; //
        uint256 leverageRatio = 2*1e18;
        uint256 ethAmount = wbtcRise.previewInitialize(collateralAmount, nav, leverageRatio);

        // Slippage tolerance 3%
        ethAmount += (0.3 ether * ethAmount) / 1 ether;
        wbtcRise.initialize{value: ethAmount}(collateralAmount, nav, leverageRatio); // This should be reverted to Slippage Too High

        // Check the parameters
        assertTrue(wbtcRise.isInitialized());
        assertEq(wbtcRise.totalCollateral(), 2 * collateralAmount, "check total collateral");

        uint256 debt = (collateralAmount * oracleAdapterCached.price(wbtc, usdc)) / 1e8;
        assertEq(wbtcRise.totalDebt(), debt, "check total debt");

        assertGt(wbtcRise.totalSupply(), 0, "check rise token supply");
        assertEq(wbtcRise.totalSupply(), wbtcRise.balanceOf(address(this)), "check rise token supply");

        assertGt(wbtcRise.nav(), nav - 1e6, "check nav");
        assertLt(wbtcRise.nav(), nav + 1e6, "check nav");
        assertGt(wbtcRise.leverageRatio(), leverageRatio - 0.001 ether, "check leverage ratio");
        assertLt(wbtcRise.leverageRatio(), leverageRatio + 0.001 ether, "check leverage ratio");
    }

    function testInitializeWBTCRISEWithLeverageRatio1point69x() public {
        // Create factory
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient, address(uniswapAdapterCached), address(oracleAdapterCached));

        // Create new Rise token
        IRiseToken wbtcRise = IRiseToken(factory.create(fwbtc, fusdc));

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.9 * 1e8; // This might be change in the future, min borrow on mainnet is 1ETH
        uint256 leverageRatio = 1.69 * 1e18;
        uint256 ethAmount = wbtcRise.previewInitialize(collateralAmount, nav, leverageRatio);

        // Slippage tolerance 3%
        ethAmount += (0.3 ether * ethAmount) / 1 ether;
        wbtcRise.initialize{value: ethAmount}(collateralAmount, nav, leverageRatio); // This should be reverted to Slippage Too High

        // Check the parameters
        assertTrue(wbtcRise.isInitialized());

        assertGt(wbtcRise.totalSupply(), 0, "check rise token supply");
        assertEq(wbtcRise.totalSupply(), wbtcRise.balanceOf(address(this)), "check rise token supply");

        assertGt(wbtcRise.nav(), nav - 1e6, "check nav");
        assertLt(wbtcRise.nav(), nav + 1e6, "check nav");
        assertGt(wbtcRise.leverageRatio(), leverageRatio - 0.001 ether, "check leverage ratio");
        assertLt(wbtcRise.leverageRatio(), leverageRatio + 0.001 ether, "check leverage ratio");
    }

    function testInitializeWBTCRISEWithLeverageRatio2point5x() public {
        // Create factory
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient, address(uniswapAdapterCached), address(oracleAdapterCached));

        // Create new Rise token
        IRiseToken wbtcRise = IRiseToken(factory.create(fwbtc, fusdc));

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.08 * 1e8; //
        uint256 leverageRatio = 2.5 * 1e18;
        uint256 ethAmount = wbtcRise.previewInitialize(collateralAmount, nav, leverageRatio);

        // Slippage tolerance 3%
        ethAmount += (0.3 ether * ethAmount) / 1 ether;
        wbtcRise.initialize{value: ethAmount}(collateralAmount, nav, leverageRatio); // This should be reverted to Slippage Too High

        // Check the parameters
        assertTrue(wbtcRise.isInitialized());

        assertGt(wbtcRise.totalSupply(), 0, "check rise token supply");
        assertEq(wbtcRise.totalSupply(), wbtcRise.balanceOf(address(this)), "check rise token supply");

        assertGt(wbtcRise.nav(), nav - 1e6, "check nav");
        assertLt(wbtcRise.nav(), nav + 1e6, "check nav");
        assertGt(wbtcRise.leverageRatio(), leverageRatio - 0.001 ether, "check leverage ratio");
        assertLt(wbtcRise.leverageRatio(), leverageRatio + 0.001 ether, "check leverage ratio");
    }

    function testInitializeWBTCRISERefundExcessETH() public {
        // Create factory
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient, address(uniswapAdapterCached), address(oracleAdapterCached));

        // Create new Rise token
        IRiseToken wbtcRise = IRiseToken(factory.create(fwbtc, fusdc));

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.08 * 1e8; //
        uint256 leverageRatio = 2 * 1e18;
        uint256 ethAmount = wbtcRise.previewInitialize(collateralAmount, nav, leverageRatio);

        uint256 prevBalance = address(this).balance;
        ethAmount += (2 * ethAmount);
        wbtcRise.initialize{value: ethAmount}(collateralAmount, nav, leverageRatio);

        // Check the parameters
        assertTrue(wbtcRise.isInitialized());
        assertEq(wbtcRise.totalCollateral(), 2 * collateralAmount, "check total collateral");

        uint256 debt = (collateralAmount * oracleAdapterCached.price(wbtc, usdc)) / 1e8;
        assertEq(wbtcRise.totalDebt(), debt, "check total debt");

        assertGt(wbtcRise.totalSupply(), 0, "check rise token supply");
        assertEq(wbtcRise.totalSupply(), wbtcRise.balanceOf(address(this)), "check rise token supply");

        assertGt(wbtcRise.nav(), nav - 1e6, "check nav");
        assertLt(wbtcRise.nav(), nav + 1e6, "check nav");
        assertGt(wbtcRise.leverageRatio(), leverageRatio - 0.001 ether, "check leverage ratio");
        assertLt(wbtcRise.leverageRatio(), leverageRatio + 0.001 ether, "check leverage ratio");

        // Make sure ETH is refunded
        assertGt(address(this).balance, prevBalance - ethAmount, "check excess ETH refund");
    }

    function testPreviewBuyWithZeroShares() public {
        assertEq(wbtcRiseCached.previewBuy(0), 0, "check preview amount");
    }

    function testPreviewBuyWithNonInitializedRiseToken() public {
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient, address(uniswapAdapterCached), address(oracleAdapterCached));
        IRiseToken wbtcRise = IRiseToken(factory.create(fwbtc, fusdc));
        assertEq(wbtcRise.previewBuy(1e8), 0, "check preview amount");
    }

    function testFailPreviewBuyRevertIfTheTokenIsNotConfiguredInOracleAdapter() public {
        // Preview with zero shares
        address randomToken = hevm.addr(1);
        wbtcRiseCached.previewBuy(1e8, randomToken);
    }

    function testPreviewBuyGetETHAmount() public {
        uint256 ethAmount = wbtcRiseCached.previewBuy(1e8);
        assertGt(ethAmount, 0.1 ether, "check min amount");
        assertLt(ethAmount, 0.2 ether, "check max amount");
    }

    function testPreviewBuyGetUSDCAmount() public {
        uint256 usdcAmount = wbtcRiseCached.previewBuy(1e8, usdc);
        assertGt(usdcAmount, 350 * 1e6, "check min amount");
        assertLt(usdcAmount, 405 * 1e6, "check max amount");
    }

    function testFailBuyRevertIfRiseTokenNotInitialized() public {
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient, address(uniswapAdapterCached), address(oracleAdapterCached));
        IRiseToken wbtcRise = IRiseToken(factory.create(fwbtc, fusdc));
        uint256 shares = 1e8;
        uint256 ethAmount = wbtcRise.previewBuy(shares);
        ethAmount += (0.03 ether * ethAmount) / 1 ether; // slippage 3%
        wbtcRise.buy{value: ethAmount}(shares, address(this));
    }

    function testFailBuyRevertIfMoreThanMaxBuy() public {
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient, address(uniswapAdapterCached), address(oracleAdapterCached));
        IRiseToken wbtcRise = IRiseToken(factory.create(fwbtc, fusdc));
        wbtcRise.setMaxBuy(2 * 1e8);

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.08 * 1e8; //
        uint256 leverageRatio = 2 * 1e18;
        uint256 ethAmount = wbtcRise.previewInitialize(collateralAmount, nav, leverageRatio);

        // Slippage tolerance 3%
        ethAmount += (0.3 ether * ethAmount) / 1 ether;
        wbtcRise.initialize{value: ethAmount}(collateralAmount, nav, leverageRatio);

        uint256 shares = 5 * 1e8;
        ethAmount = wbtcRise.previewBuy(shares);
        ethAmount += (0.03 ether * ethAmount) / 1 ether; // slippage 3%
        wbtcRise.buy{value: ethAmount}(shares, address(this));
    }

    function testFailBuyWithETHRevertIfSlippageIsTooHigh() public {
        uint256 shares = 5 * 1e8;
        uint256 ethAmount = wbtcRiseCached.previewBuy(shares);
        ethAmount -= (0.05 ether * ethAmount) / 1 ether; // slippage -5% to test out the revert
        wbtcRiseCached.buy{value: ethAmount}(shares, address(this));
    }

    function testFailBuyWithUSDCRevertIfSlippageIsTooHigh() public {
        uint256 shares = 5 * 1e8;
        uint256 usdcAmount = wbtcRiseCached.previewBuy(shares, usdc);
        usdcAmount -= (0.05 ether * usdcAmount) / 1 ether; // slippage -5% to test out the revert

        // Top up user balance
        hevm.setUSDCBalance(address(this), usdcAmount);
        IERC20(usdc).approve(address(wbtcRiseCached), usdcAmount);
        wbtcRiseCached.buy(shares, address(this), usdc, usdcAmount);
    }

    function testBuyWithETH() public {
        uint256 shares = 5 * 1e8;
        uint256 ethAmount = wbtcRiseCached.previewBuy(shares);
        ethAmount += (0.03 ether * ethAmount) / 1 ether; // slippage tolerance +3%

        // Make sure this is not changed
        uint256 cps = wbtcRiseCached.collateralPerShares();
        uint256 dps = wbtcRiseCached.debtPerShares();
        uint256 nav = wbtcRiseCached.nav();
        uint256 lr  = wbtcRiseCached.leverageRatio();

        // buy with ETH
        address recipient = hevm.addr(16);
        wbtcRiseCached.buy{value: ethAmount}(shares, recipient);

        // Check make sure user receive the token
        assertEq(wbtcRiseCached.balanceOf(recipient), shares, "check user balance");
        assertEq(wbtcRiseCached.balanceOf(feeRecipient), (0.001 ether * shares) / 1 ether, "check fee recipient balance");

        // Make sure the value don't change after buy
        assertEq(wbtcRiseCached.collateralPerShares(), cps, "check cps");
        assertEq(wbtcRiseCached.debtPerShares(), dps, "check dps");
        assertEq(wbtcRiseCached.nav(), nav, "check nav");
        assertEq(wbtcRiseCached.leverageRatio(), lr, "check leverage ratio");
    }

    function testBuyWithETHExcessRefunded() public {
        uint256 shares = 5 * 1e8;
        uint256 ethAmount = wbtcRiseCached.previewBuy(shares);
        ethAmount += (0.1 ether * ethAmount) / 1 ether; // slippage tolerance +10%

        // buy with ETH
        uint256 prevBalance = address(this).balance;
        wbtcRiseCached.buy{value: ethAmount}(shares, address(this));

        assertGt(address(this).balance, prevBalance - ethAmount);
    }

    function testBuyWithETHAndCustomRecipient() public {
        uint256 shares = 5 * 1e8;
        uint256 ethAmount = wbtcRiseCached.previewBuy(shares);
        ethAmount += (0.03 ether * ethAmount) / 1 ether; // slippage tolerance +3%

        // buy with ETH
        address recipient = hevm.addr(1);
        wbtcRiseCached.buy{value: ethAmount}(shares, recipient);

        // Check make sure user receive the token
        assertEq(wbtcRiseCached.balanceOf(recipient), shares, "check user balance");
        assertEq(wbtcRiseCached.balanceOf(feeRecipient), (0.001 ether * shares) / 1 ether, "check fee recipient balance");
    }

    function testBuyWithUSDC() public {
        uint256 shares = 5 * 1e8;
        uint256 usdcAmountInMax = wbtcRiseCached.previewBuy(shares, usdc);
        usdcAmountInMax += (0.03 ether * usdcAmountInMax) / 1 ether; // slippage tolerance +3%

        // Make sure this is not changed
        uint256 cps = wbtcRiseCached.collateralPerShares();
        uint256 dps = wbtcRiseCached.debtPerShares();
        uint256 nav = wbtcRiseCached.nav();
        uint256 lr  = wbtcRiseCached.leverageRatio();

        // buy with USDC
        address recipient = hevm.addr(16);
        hevm.setUSDCBalance(address(this), usdcAmountInMax);
        IERC20(usdc).approve(address(wbtcRiseCached), usdcAmountInMax);
        wbtcRiseCached.buy(shares, recipient, usdc, usdcAmountInMax);
        IERC20(usdc).approve(address(wbtcRiseCached), 0);

        // Check make sure user receive the token
        assertEq(wbtcRiseCached.balanceOf(recipient), shares, "check user balance");
        assertEq(wbtcRiseCached.balanceOf(feeRecipient), (0.001 ether * shares) / 1 ether, "check fee recipient balance");

        // Make sure the value don't change after buy
        assertEq(wbtcRiseCached.collateralPerShares(), cps, "check cps");
        assertEq(wbtcRiseCached.debtPerShares(), dps, "check dps");
        assertEq(wbtcRiseCached.nav(), nav, "check nav");
        assertEq(wbtcRiseCached.leverageRatio(), lr, "check leverage ratio");
    }

    function testBuyWithUSDCExcessRefunded() public {
        uint256 shares = 5 * 1e8;
        uint256 usdcAmountInMax = wbtcRiseCached.previewBuy(shares, usdc);
        usdcAmountInMax += (0.1 ether * usdcAmountInMax) / 1 ether; // slippage tolerance +10%

        // buy with USDC
        hevm.setUSDCBalance(address(this), usdcAmountInMax);
        uint256 prevBalance = IERC20(usdc).balanceOf(address(this));
        IERC20(usdc).approve(address(wbtcRiseCached), usdcAmountInMax);
        wbtcRiseCached.buy(shares, address(this), usdc, usdcAmountInMax);
        IERC20(usdc).approve(address(wbtcRiseCached), 0);

        assertGt(IERC20(usdc).balanceOf(address(this)), prevBalance - usdcAmountInMax);
    }

    function testBuyWithUSDCAndCustomRecipient() public {
        uint256 shares = 5 * 1e8;
        uint256 usdcAmountInMax = wbtcRiseCached.previewBuy(shares, usdc);
        usdcAmountInMax += (0.03 ether * usdcAmountInMax) / 1 ether; // slippage tolerance +3%

        // buy with USDC
        address recipient = hevm.addr(1);
        hevm.setUSDCBalance(address(this), usdcAmountInMax);
        IERC20(usdc).approve(address(wbtcRiseCached), usdcAmountInMax);
        wbtcRiseCached.buy(shares, recipient, usdc, usdcAmountInMax);
        IERC20(usdc).approve(address(wbtcRiseCached), 0);

        // Check make sure user receive the token
        assertEq(wbtcRiseCached.balanceOf(recipient), shares, "check user balance");
        assertEq(wbtcRiseCached.balanceOf(feeRecipient), (0.001 ether * shares) / 1 ether, "check fee recipient balance");
    }

    receive() external payable {}
}

