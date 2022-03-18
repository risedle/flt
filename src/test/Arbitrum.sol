// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

// ERC20 addresses on Arbitrum
address constant gohm = 0x8D9bA570D6cb60C7e3e0F31343Efe75AB8E65FB1;
address constant usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
address constant fgohm = 0xd861026A12623aec769fA57D05201193D8844368;
address constant fusdc = 0x156157693BA371c5B126AAeF784D2853EbC8fEFa;

// ERC20 slots on Arbitrum to manipulate the token balance
uint256 constant usdcSlot = 51;
uint256 constant gohmSlot = 101;
uint256 constant wethSlot = 51;