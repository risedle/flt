// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

import { IVM } from "./IVM.sol";
import { VMUtils } from "./VMUtils.sol";
import { usdc, gohm, wbtc, weth } from "chain/Tokens.sol";

/**
 * @title VM Utils Test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract VMUtilsTest {

    /// ███ Storages █████████████████████████████████████████████████████████

    IVM     private vm = IVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    VMUtils private utils;


    /// ███ Test Setup ███████████████████████████████████████████████████████

    function setUp() public {
        utils = new VMUtils(vm);
    }


    /// ███ Tests  ███████████████████████████████████████████████████████████

    function testSetUSDCBalance() public {
        IERC20 token = IERC20(usdc);
        address account = vm.addr(1);
        uint256 amount = 100 * 1e6; // 100 USDC

        // Set the balance
        utils.setUSDCBalance(account, amount);

        // Check the balance
        uint256 balance = token.balanceOf(account);

        // Make sure it's updated
        require(amount == balance, "USDC: invalid balance");
    }

    function testSetGOHMBalance() public {
        IERC20 token = IERC20(gohm);
        address account = vm.addr(1);
        uint256 amount = 100 ether; // 100 gOHM

        // Set the balance
        utils.setGOHMBalance(account, amount);

        // Check the balance
        uint256 balance = token.balanceOf(account);

        // Make sure it's updated
        require(amount == balance, "GOHM: invalid balance");
    }

    function testSetWBTCBalance() public {
        IERC20 token = IERC20(wbtc);
        address account = vm.addr(1);
        uint256 amount = 100 * 1e8; // 100 WBTC

        // Set the balance
        utils.setWBTCBalance(account, amount);

        // Check the balance
        uint256 balance = token.balanceOf(account);

        // Make sure it's updated
        require(amount == balance, "WBTC: invalid balance");
    }

    function testSetWETHBalance() public {
        IERC20 token = IERC20(weth);
        address account = vm.addr(1);
        uint256 amount = 100 ether; // 100 WETH

        // Set the balance
        utils.setWETHBalance(account, amount);

        // Check the balance
        uint256 balance = token.balanceOf(account);

        // Make sure it's updated
        require(amount == balance, "WETH: invalid balance");
    }
}

