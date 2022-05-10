// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IVM } from "./IVM.sol";

import { usdc, usdcSlot } from "chain/Tokens.sol";
import { gohm, gohmSlot } from "chain/Tokens.sol";
import { wbtc, wbtcSlot } from "chain/Tokens.sol";
import { weth, wethSlot } from "chain/Tokens.sol";

/**
 * @title VM Utilities
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Utility functions to interact with mainnet forking
 */
contract VMUtils {

    /// ███ Storages █████████████████████████████████████████████████████████

    IVM private immutable vm;


    /// ███ Constructor ██████████████████████████████████████████████████████

    constructor(IVM _vm) {
        vm = _vm;
    }


    /// ███ Utilities ████████████████████████████████████████████████████████

    function setUSDCBalance(address account, uint256 amount) public {
        vm.store(
            usdc,
            keccak256(abi.encode(account, usdcSlot)),
            bytes32(amount)
        );
    }

    function setGOHMBalance(address account, uint256 amount) public {
        vm.store(
            gohm,
            keccak256(abi.encode(account, gohmSlot)),
            bytes32(amount)
        );
    }

    function setWBTCBalance(address account, uint256 amount) public {
        vm.store(
            wbtc,
            keccak256(abi.encode(account, wbtcSlot)),
            bytes32(amount)
        );
    }

    function setWETHBalance(address account, uint256 amount) public {
        vm.store(
            weth,
            keccak256(abi.encode(account, wethSlot)),
            bytes32(amount)
        );
    }
}
