// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

address constant USDC_ADDRESS = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
uint256 constant USDC_SLOT = 51;
address constant GOHM_ADDRESS = 0x8D9bA570D6cb60C7e3e0F31343Efe75AB8E65FB1;
uint256 constant GOHM_SLOT = 101;

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
}

contract HEVM {
    IHEVM internal hevm;

    constructor() {
        hevm = IHEVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    }

    function addr(uint256 sk) external returns (address) {
        return hevm.addr(sk);
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