// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { HEVM } from "../hevm/HEVM.sol";
import { RariFusePriceOracleAdapter } from "../../oracles/RariFusePriceOracleAdapter.sol";
import { gohm, rariFuseGOHMPriceOracle } from "chain/Tokens.sol";
import { usdc, rariFuseUSDCPriceOracle } from "chain/Tokens.sol";
import { IRariFusePriceOracle } from "../../interfaces/IRariFusePriceOracle.sol";

/**
 * @title Rari Fuse Price Oracle Adapter Test
 * @author bayu <bayu@risedle.com> <github.com/pyk>
 */
contract RariFusePriceOracleAdapterTest is DSTest {
    HEVM private hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    /// @notice Make sure non-owner cannot configure the oracle
    function testFailNonOwnerCannotConfigureOracle() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Transfer ownership
        address newOwner = hevm.addr(1);
        oracle.transferOwnership(newOwner);

        // Configure oracle for token
        oracle.configure(gohm, rariFuseGOHMPriceOracle);
    }

    /// @notice Make sure owner can set the oracle
    function testOwnerCanSetOracle() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for token
        oracle.configure(gohm, rariFuseGOHMPriceOracle);

        // Check the metadata
        (IRariFusePriceOracle priceOracle, uint8 decimals) = oracle.oracles(gohm);
        assertEq(address(priceOracle), rariFuseGOHMPriceOracle);
        assertEq(decimals, 18);
    }

    /// @notice Make sure it revert when base oracle is not configured
    function testFailPriceRevertIfBaseOracleNotConfigured() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for tokens
        oracle.configure(usdc, rariFuseUSDCPriceOracle);

        // Base is not configured, it should be reverted
        oracle.price(gohm, usdc);
    }

    /// @notice Make sure it revert when quote oracle is not configured
    function testFailPriceRevertIfQuoteOracleNotConfigured() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for tokens
        oracle.configure(gohm, rariFuseGOHMPriceOracle);

        // Base is not configured, it should be reverted
        oracle.price(gohm, usdc);
    }

    /// @notice Make sure it revert when token oracle is not configured
    function testFailPriceRevertIfTokenOracleNotConfigured() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Base is not configured, it should be reverted
        oracle.price(gohm);
    }

    /// @notice Make sure it returns correctly
    function testPriceGOHMUSDC() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for tokens
        oracle.configure(gohm, rariFuseGOHMPriceOracle);
        oracle.configure(usdc, rariFuseUSDCPriceOracle);

        // Base is not configured, it should be reverted
        uint256 price = oracle.price(gohm, usdc);
        assertGt(price, 2_000 * 1e6, "check price");
        assertLt(price, 6_000 * 1e6, "check price");
    }

    /// @notice Make sure it returns correctly
    function testPriceGOHMETH() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for tokens
        oracle.configure(gohm, rariFuseGOHMPriceOracle);

        // Base is not configured, it should be reverted
        uint256 price = oracle.price(gohm);
        assertLt(price, 5 ether);
    }

    /// @notice Make sure isConfigured returns correct value
    function testIsConfigured() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for tokens
        oracle.configure(gohm, rariFuseGOHMPriceOracle);

        // Check configured value
        assertTrue(oracle.isConfigured(gohm), "gohm");
        assertTrue(!oracle.isConfigured(usdc), "usdc");
    }

}
