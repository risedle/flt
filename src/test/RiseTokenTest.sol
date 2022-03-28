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

    function setUp() public {
        hevm = new HEVM();

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
    }

    function testFailPreviewInitializeRevertIfCollateralTokenIsNotConfiguredInOracleAdapter() public {
        // Create new factory
        UniswapAdapter uniswapAdapter = new UniswapAdapter(weth);
        uniswapAdapter.configure(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);
        uniswapAdapter.configure(usdc, 3, uniswapV3USDCETHPool, uniswapV3Router);

        RariFusePriceOracleAdapter oracleAdapter = new RariFusePriceOracleAdapter();
        // oracleAdapter.configure(wbtc, rariFuseWBTCPriceOracle);
        oracleAdapter.configure(usdc, rariFuseUSDCPriceOracle);

        RiseTokenFactory factory = new RiseTokenFactory(address(uniswapAdapter), address(oracleAdapter));

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

        RiseTokenFactory factory = new RiseTokenFactory(address(uniswapAdapter), address(oracleAdapter));

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

        RiseTokenFactory factory = new RiseTokenFactory(address(uniswapAdapter), address(oracleAdapter));

        // Create new Rise token
        IRiseToken wbtcRise = IRiseToken(factory.create(fwbtc, fusdc));

        // Initialize WBTCRISE with 400USDC nav, 0.01 BTC initial collateral and 2x leverage ratio
        uint256 ethAmount = wbtcRise.previewInitialize(0.01 * 1e8, 400 * 1e6, 2*1e18);
        assertLt(ethAmount, 1 ether);
    }

    function testFailInitializeWBTCRISERevertIfSlippageTooHigh() public {
        // Create factory
        RiseTokenFactory factory = new RiseTokenFactory(address(uniswapAdapterCached), address(oracleAdapterCached));

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
        RiseTokenFactory factory = new RiseTokenFactory(address(uniswapAdapterCached), address(oracleAdapterCached));

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
        RiseTokenFactory factory = new RiseTokenFactory(address(uniswapAdapterCached), address(oracleAdapterCached));

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
        RiseTokenFactory factory = new RiseTokenFactory(address(uniswapAdapterCached), address(oracleAdapterCached));

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
        RiseTokenFactory factory = new RiseTokenFactory(address(uniswapAdapterCached), address(oracleAdapterCached));

        // Create new Rise token
        IRiseToken wbtcRise = IRiseToken(factory.create(fwbtc, fusdc));

        // Initialize WBTCRISE
        uint256 nav = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 0.08 * 1e8; //
        uint256 leverageRatio = 2 * 1e18;
        uint256 ethAmount = wbtcRise.previewInitialize(collateralAmount, nav, leverageRatio);

        // Slippage tolerance 3%
        uint256 prevBalance = address(this).balance;
        ethAmount += (2 * ethAmount);
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

        // Make sure ETH is refunded
        assertGt(address(this).balance, prevBalance - ethAmount, "check excess ETH refund");
    }

    receive() external payable {}
}

