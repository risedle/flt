// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { HEVM } from "./hevm/HEVM.sol";
import { RiseTokenFactory } from "../RiseTokenFactory.sol";
import { UniswapAdapter } from "../uniswap/UniswapAdapter.sol";
import { RariFusePriceOracleAdapter } from "../oracles/RariFusePriceOracleAdapter.sol";
import { weth, wbtc, usdc } from "chain/Tokens.sol";
import { fgohm, fusdc, fwbtc } from "chain/Tokens.sol";
import { rariFuseUSDCPriceOracle, rariFuseWBTCPriceOracle } from "chain/Tokens.sol";
import { uniswapV3WBTCETHPool, uniswapV3USDCETHPool, uniswapV3Router } from "chain/Tokens.sol";
import { IRiseToken } from "../interfaces/IRiseToken.sol";

/**
 * @title Rise Token Factory Test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract RiseTokenFactoryTest is DSTest {

    HEVM private hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    /// @notice Test default state
    function testDefaultStorages() public {
        // Create new factory
        address adapter = hevm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(adapter, adapter);

        // Check
        assertEq(factory.feeRecipient(), address(this), "check fee recipient");
        assertEq(address(factory.uniswapAdapter()), adapter, "check uniswap adapter");
        assertEq(address(factory.oracleAdapter()), adapter, "check oracle adapter");
    }

    /// @notice Non-owner cannot set fee recipient
    function testFailNonOwnerCannotSetFeeRecipient() public {
        // Create new factory
        address adapter = hevm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(adapter, adapter);

        // Transfer ownership
        address newOwner = hevm.addr(2);
        factory.transferOwnership(newOwner);

        // Non-owner trying to set the fee recipient; It should be reverted
        address recipient = hevm.addr(3);
        factory.setFeeRecipient(recipient);
    }

    /// @notice Owner can set fee recipient
    function testOwnerCanSetFeeRecipient() public {
        // Create new factory
        address adapter = hevm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(adapter, adapter);

        // Non-owner trying to set the fee recipient; It should be reverted
        address recipient = hevm.addr(2);
        factory.setFeeRecipient(recipient);

        // Check
        assertEq(factory.feeRecipient(), recipient);
    }

    /// @notice Create should revert if collateral is not configured in Uniswap Adapter
    function testFailCreateRevertIfCollateralNotConfiguredInUniswapAdapter() public {
        // Create new factory
        address adapter = hevm.addr(1);
        UniswapAdapter uniswapAdapter = new UniswapAdapter(weth);
        RiseTokenFactory factory = new RiseTokenFactory(address(uniswapAdapter), adapter);

        // Configure Uniswap Adapter
        uniswapAdapter.configure(usdc, 3, uniswapV3USDCETHPool, uniswapV3Router);

        // This should revert
        factory.create(fwbtc, fusdc);
    }

    /// @notice Create should revert if debt is not configured in Uniswap Adapter
    function testFailCreateRevertIfDebtNotConfiguredInUniswapAdapter() public {
        // Create new factory
        address adapter = hevm.addr(1);
        UniswapAdapter uniswapAdapter = new UniswapAdapter(weth);
        RiseTokenFactory factory = new RiseTokenFactory(address(uniswapAdapter), adapter);

        // Configure Uniswap Adapter
        uniswapAdapter.configure(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);

        // This should revert
        factory.create(fwbtc, fusdc);
    }

    /// @notice Create should revert if collateral is not configured in Oracle Adapter
    function testFailCreateRevertIfCollateralNotConfiguredInOracleAdapter() public {
        // Create new factory
        UniswapAdapter uniswapAdapter = new UniswapAdapter(weth);
        RariFusePriceOracleAdapter oracleAdapter = new RariFusePriceOracleAdapter();
        RiseTokenFactory factory = new RiseTokenFactory(address(uniswapAdapter), address(oracleAdapter));

        // Configure Uniswap Adapter
        uniswapAdapter.configure(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);
        uniswapAdapter.configure(usdc, 3, uniswapV3USDCETHPool, uniswapV3Router);

        // Configure Oracle Adapter
        oracleAdapter.configure(usdc, rariFuseUSDCPriceOracle);

        // This should revert
        factory.create(fwbtc, fusdc);
    }

    /// @notice Create should revert if debt is not configured in Uniswap Adapter
    function testFailCreateRevertIfDebtNotConfiguredInOracleAdapter() public {
        // Create new factory
        UniswapAdapter uniswapAdapter = new UniswapAdapter(weth);
        RariFusePriceOracleAdapter oracleAdapter = new RariFusePriceOracleAdapter();
        RiseTokenFactory factory = new RiseTokenFactory(address(uniswapAdapter), address(oracleAdapter));

        // Configure Uniswap Adapter
        uniswapAdapter.configure(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);
        uniswapAdapter.configure(usdc, 3, uniswapV3USDCETHPool, uniswapV3Router);

        // Configure Oracle Adapter
        oracleAdapter.configure(wbtc, rariFuseWBTCPriceOracle);

        // This should revert
        factory.create(fwbtc, fusdc);
    }

    /// @notice Non-owner cannot create token
    function testFailNonOwnerCannotCreateRiseToken() public {
        // Create new factory
        address adapter = hevm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(adapter, adapter);

        // Transfer ownership
        address newOwner = hevm.addr(2);
        factory.transferOwnership(newOwner);

        // Non-owner trying to set the fee recipient; It should be reverted
        factory.create(fwbtc, fusdc);
    }

    /// @notice Owner can set fee recipient
    function testOwnerCanCreateRiseToken() public {
        // Create new factory
        UniswapAdapter uniswapAdapter = new UniswapAdapter(weth);
        RariFusePriceOracleAdapter oracleAdapter = new RariFusePriceOracleAdapter();
        RiseTokenFactory factory = new RiseTokenFactory(address(uniswapAdapter), address(oracleAdapter));

        // Configure Uniswap Adapter
        uniswapAdapter.configure(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);
        uniswapAdapter.configure(usdc, 3, uniswapV3USDCETHPool, uniswapV3Router);

        // Configure Oracle Adapter
        oracleAdapter.configure(wbtc, rariFuseWBTCPriceOracle);
        oracleAdapter.configure(usdc, rariFuseUSDCPriceOracle);

        // Create new token
        address _token = factory.create(fwbtc, fusdc);

        // Check public properties
        assertEq(IERC20Metadata(_token).name(), "WBTC 2x Long Risedle");
        assertEq(IERC20Metadata(_token).symbol(), "WBTCRISE");
        assertEq(IERC20Metadata(_token).decimals(), 8);
        assertEq(address(IRiseToken(_token).factory()), address(factory));
        assertEq(address(IRiseToken(_token).collateral()), wbtc);
        assertEq(address(IRiseToken(_token).debt()), usdc);
        assertEq(address(IRiseToken(_token).fCollateral()), fwbtc);
        assertEq(address(IRiseToken(_token).fDebt()), fusdc);
        assertEq(IRiseToken(_token).owner(), address(this));
        assertEq(address(IRiseToken(_token).uniswapAdapter()), address(factory.uniswapAdapter()));
        assertEq(address(IRiseToken(_token).oracleAdapter()), address(factory.oracleAdapter()));
    }

}