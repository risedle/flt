// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { FuseLeveragedToken } from "../FuseLeveragedToken.sol";
import { HEVM } from "./HEVM.sol";
import { gohm, usdc } from "./Arbitrum.sol";

/**
 * @title Fuse Leveraged Token Access Control Test
 * @author bayu (github.com/pyk)
 * @notice Make sure the access control works as expected
 */
contract FuseLeveragedTokenAccessControlTest is DSTest {
    HEVM private hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    /// @notice Make sure non-owner cannot set the maxDeposit value
    function testFailNonOwnerCannotSetMaxDeposit() public {
        // Create new FLT; by default the deployer is the owner
        address dummy = hevm.addr(100);
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", gohm, usdc, dummy, dummy, dummy, dummy);

        // Transfer the ownership
        address newOwner = hevm.addr(1);
        flt.transferOwnership(newOwner);

        // Non-owner trying to set the maxDeposit value
        flt.setMaxDeposit(1 ether); // This should be failed
    }

    /// @notice Make sure owner can set the maxDeposit value
    function testOwnerCanSetMaxDeposit() public {
        // Create new FLT; by default the deployer is the owner
        address dummy = hevm.addr(100);
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", gohm, usdc, dummy, dummy, dummy, dummy);

        // Make sure the default value is set
        assertEq(flt.maxDeposit(), type(uint256).max);

        // Owner set the maxDeposit
        uint256 newMaxDeposit = 1 ether;
        flt.setMaxDeposit(newMaxDeposit);

        // Make sure the value is updated
        assertEq(flt.maxDeposit(), newMaxDeposit);
    }

    /// @notice Make sure non-owner cannot call the bootstrap function
    function testNonOwnerCannotBootstrapTheFLT() public {
        // Create new FLT; by default the deployer is the owner

    }
}
