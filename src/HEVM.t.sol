// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { HEVM, USDC_ADDRESS, GOHM_ADDRESS } from "./HEVM.sol";

contract HEVMTest is DSTest {
    HEVM internal hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    function testSetUSDCBalance() public {
        IERC20 token = IERC20(USDC_ADDRESS);
        address account = hevm.addr(1);
        uint256 amount = 100 * 1e6; // 100 USDC

        // Set the balance
        hevm.setUSDCBalance(account, amount);

        // Check the balance
        uint256 balance = token.balanceOf(account);

        // Make sure it's updated
        assertEq(amount, balance);
    }

    function testSetGOHMBalance() public {
        IERC20 token = IERC20(GOHM_ADDRESS);
        address account = hevm.addr(1);
        uint256 amount = 100 ether; // 100 gOHM

        // Set the balance
        hevm.setGOHMBalance(account, amount);

        // Check the balance
        uint256 balance = token.balanceOf(account);

        // Make sure it's updated
        assertEq(balance, amount);
    }
}