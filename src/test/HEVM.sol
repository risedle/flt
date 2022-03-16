// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { USDC_ADDRESS, USDC_SLOT } from "./Addresses.sol";
import { GOHM_ADDRESS, GOHM_SLOT } from "./Addresses.sol";

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
        hevm.store(USDC_ADDRESS, keccak256(abi.encode(account, USDC_SLOT)), bytes32(amount));
    }

    function setGOHMBalance(address account, uint256 amount) public {
        hevm.store(GOHM_ADDRESS, keccak256(abi.encode(account, GOHM_SLOT)), bytes32(amount));
    }
}
