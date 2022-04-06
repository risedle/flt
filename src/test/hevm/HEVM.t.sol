// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "ds-test/test.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

import { HEVM } from "./HEVM.sol";
import { usdc, gohm, wbtc, weth } from "chain/Tokens.sol";

contract HEVMTest is DSTest {
    HEVM internal hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    function testSetUSDCBalance() public {
        IERC20 token = IERC20(usdc);
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
        IERC20 token = IERC20(gohm);
        address account = hevm.addr(1);
        uint256 amount = 100 ether; // 100 gOHM

        // Set the balance
        hevm.setGOHMBalance(account, amount);

        // Check the balance
        uint256 balance = token.balanceOf(account);

        // Make sure it's updated
        assertEq(balance, amount);
    }

    function testSetWBTCBalance() public {
        IERC20 token = IERC20(wbtc);
        address account = hevm.addr(1);
        uint256 amount = 100 * 1e8; // 100 WBTC

        // Set the balance
        hevm.setWBTCBalance(account, amount);

        // Check the balance
        uint256 balance = token.balanceOf(account);

        // Make sure it's updated
        assertEq(balance, amount);
    }

    function testSetWETHBalance() public {
        IERC20 token = IERC20(weth);
        address account = hevm.addr(1);
        uint256 amount = 100 ether; // 100 WETH

        // Set the balance
        hevm.setWETHBalance(account, amount);

        // Check the balance
        uint256 balance = token.balanceOf(account);

        // Make sure it's updated
        assertEq(balance, amount);
    }
}