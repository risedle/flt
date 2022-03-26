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

    /// @notice Make sure non-owner can set the oracle
    function testFailNonOwnerCannotSetOracle() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Transfer ownership
        address newOwner = hevm.addr(1);
        oracle.transferOwnership(newOwner);

        // Set oracle for token
        oracle.setOracle(gohm, rariFuseGOHMPriceOracle);
    }

    /// @notice Make sure owner can set the oracle
    function testOwnerCanSetOracle() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Set oracle for token
        oracle.setOracle(gohm, rariFuseGOHMPriceOracle);

        // Check the metadata
        (IRariFusePriceOracle priceOracle, uint8 decimals) = oracle.oracles(gohm);
        assertEq(address(priceOracle), rariFuseGOHMPriceOracle);
        assertEq(decimals, 18);
    }
}
