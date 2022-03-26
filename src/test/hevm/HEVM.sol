// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { usdc, usdcSlot } from "chain/Tokens.sol";
import { gohm, gohmSlot } from "chain/Tokens.sol";
import { wbtc, wbtcSlot } from "chain/Tokens.sol";
import { weth, wethSlot } from "chain/Tokens.sol";

/// @notice Set Hevm interface, so we can use the cheat codes it in the test
/// @dev https://github.com/dapphub/dapptools/tree/master/src/hevm#cheat-codes
interface IHEVM {
    function addr(uint256 sk) external returns (address addr);

    function store(
        address c,
        bytes32 loc,
        bytes32 val
    ) external;

    function warp(uint256 x) external;

    function roll(uint256 x) external;
}

contract HEVM {
    IHEVM internal hevm;

    constructor() {
        hevm = IHEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    }

    function addr(uint256 sk) external returns (address) {
        return hevm.addr(sk);
    }

    function roll(uint256 _blockNumber) external {
        return hevm.roll(_blockNumber);
    }

    // Set the block.timestamp to x
    function warp(uint256 x) external {
        hevm.warp(x);
    }

    function setUSDCBalance(address account, uint256 amount) public {
        hevm.store(usdc, keccak256(abi.encode(account, usdcSlot)), bytes32(amount));
    }

    function setGOHMBalance(address account, uint256 amount) public {
        hevm.store(gohm, keccak256(abi.encode(account, gohmSlot)), bytes32(amount));
    }

    function setWBTCBalance(address account, uint256 amount) public {
        hevm.store(wbtc, keccak256(abi.encode(account, wbtcSlot)), bytes32(amount));
    }

    function setWETHBalance(address account, uint256 amount) public {
        hevm.store(weth, keccak256(abi.encode(account, wethSlot)), bytes32(amount));
    }
}
