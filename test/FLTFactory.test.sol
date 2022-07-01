// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { FLTFactory } from "../src/FLTFactory.sol";

contract FLTFactoryTest is Test {
    /// @notice Make sure revert if non-owner set fee recipient
    function testSetFeeRecipientRevertIfNonOwnerExecute() public {
        // Deploy new FLT Factory
        FLTFactory factory = new FLTFactory(vm.addr(1));

        // Transfer ownership
        address newOwner = vm.addr(2);
        factory.setOwner(newOwner);

        // Set fee recipient
        vm.expectRevert("UNAUTHORIZED");
        factory.setFeeRecipient(newOwner);
    }

    /// @notice Make sure owner can update the fee recipient
    function testSetFeeRecipient() public {
        // Deploy new FLT Factory
        FLTFactory factory = new FLTFactory(vm.addr(1));

        // Set new recipient
        address feeRecipient = vm.addr(2);
        factory.setFeeRecipient(feeRecipient);
        assertEq(factory.feeRecipient(), feeRecipient);
    }

    /// @notice Make sure revert if non-owner trying to create new token
    function testCreateRevertIfNonOwnerExecute() public {
        // Deploy new FLT Factory
        FLTFactory factory = new FLTFactory(vm.addr(1));

        // Transfer ownership
        address newOwner = vm.addr(2);
        factory.setOwner(newOwner);

        // Set fee recipient
        vm.expectRevert("UNAUTHORIZED");
        factory.create("B", "B", bytes(""), vm.addr(3));
    }
}
