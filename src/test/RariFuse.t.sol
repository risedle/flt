// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { IfERC20 } from "../interfaces/IfERC20.sol";
import { HEVM } from "./HEVM.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { GOHM_ADDRESS } from "./Addresses.sol";

address constant fgOHM = 0xd861026A12623aec769fA57D05201193D8844368;

contract RariFuseUser {
    using SafeERC20 for IERC20;

    error AddSupplyFailed();

    function addSupply(uint256 _amount) public {
        // Approve
        IERC20(GOHM_ADDRESS).safeApprove(fgOHM, _amount);

        // Mint fgOHM
        uint256 result = IfERC20(fgOHM).mint(_amount);
        if (result != 0) revert AddSupplyFailed();

        // Reset approval
        IERC20(GOHM_ADDRESS).safeApprove(fgOHM, 0);
    }
}

contract RariFuseTest is DSTest {
    HEVM internal hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    function testFuseSupply() public {
        // Create new Rari Fuse user
        RariFuseUser user = new RariFuseUser();

        // Add gOHM balance
        hevm.setGOHMBalance(address(user), 1 ether);

        hevm.roll(block.number * 100); // A hack to make sure current block number > accrual block number

        // Add supply
        user.addSupply(1 ether);

        // Make sure user have fgOHM balance
        uint256 fgOHMBalance = IERC20(fgOHM).balanceOf(address(user));

        assertGt(fgOHMBalance, 0);
    }
}
