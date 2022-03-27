// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { HEVM } from "./hevm/HEVM.sol";
import { RiseTokenFactory } from "../RiseTokenFactory.sol";

/**
 * @title Rise Token Factory Test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract RiseTokenFactoryTest is DSTest {

    HEVM private hevm;

    function setUp() public {
        hevm = new HEVM();
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

}