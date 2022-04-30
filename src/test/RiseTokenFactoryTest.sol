// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;


import "ds-test/test.sol";
import { IERC20Metadata } from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

import { IUniswapAdapter } from "../interfaces/IUniswapAdapter.sol";

import { HEVM } from "./hevm/HEVM.sol";
import { RiseTokenFactory } from "../RiseTokenFactory.sol";
import { UniswapAdapter } from "../adapters/UniswapAdapter.sol";
import { RariFusePriceOracleAdapter } from "../adapters/RariFusePriceOracleAdapter.sol";
import { weth, wbtc, usdc } from "chain/Tokens.sol";
import { fusdc, fwbtc } from "chain/Tokens.sol";
import { RiseToken } from "../RiseToken.sol";

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
        address feeRecipient = hevm.addr(2);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Check
        assertEq(factory.feeRecipient(), feeRecipient, "check fee recipient");
    }

    /// @notice Non-owner cannot set fee recipient
    function testFailNonOwnerCannotSetFeeRecipient() public {
        // Create new factory
        address feeRecipient = hevm.addr(2);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

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
        address feeRecipient = hevm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Non-owner trying to set the fee recipient; It should be reverted
        address recipient = hevm.addr(2);
        factory.setFeeRecipient(recipient);

        // Check
        assertEq(factory.feeRecipient(), recipient);
    }

    /// @notice Non-owner cannot create token
    function testFailNonOwnerCannotCreateRiseToken() public {
        // Create new factory
        address feeRecipient = hevm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Transfer ownership
        address newOwner = hevm.addr(2);
        factory.transferOwnership(newOwner);

        // Non-owner trying to set the fee recipient; It should be reverted
        factory.create(fwbtc, fusdc, hevm.addr(3), hevm.addr(4));
    }

    /// @notice Owner can set fee recipient
    function testOwnerCanCreateRiseToken() public {
        // Create new factory
        address feeRecipient = hevm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new token
        UniswapAdapter uniswapAdapter = new UniswapAdapter(weth);
        RariFusePriceOracleAdapter oracleAdapter = new RariFusePriceOracleAdapter();
        address _token = factory.create(fwbtc, fusdc, address(uniswapAdapter), address(oracleAdapter));
        RiseToken riseToken = RiseToken(payable(_token));

        // Check public properties
        assertEq(IERC20Metadata(_token).name(), "WBTC 2x Long Risedle");
        assertEq(IERC20Metadata(_token).symbol(), "WBTCRISE");
        assertEq(IERC20Metadata(_token).decimals(), 8);
        assertEq(address(riseToken.factory()), address(factory), "check factory");
        assertEq(address(riseToken.collateral()), wbtc, "check collateral");
        assertEq(address(riseToken.debt()), usdc, "check debt");
        assertEq(address(riseToken.fCollateral()), fwbtc, "check ftoken collateral");
        assertEq(address(riseToken.fDebt()), fusdc, "check ftoken debt");
        assertEq(riseToken.owner(), address(this), "check owner");
        assertEq(address(riseToken.uniswapAdapter()), address(uniswapAdapter), "check uniswap adapter");
        assertEq(address(riseToken.oracleAdapter()), address(oracleAdapter), "check oracle adapter");
    }

}