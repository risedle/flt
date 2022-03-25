// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

// ERC20 addresses on Ethereum
address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant gohm = 0x0ab87046fBb341D058F17CBC4c1133F25a20a52f;
address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

// fToken on Risedle Fuse Pools
// https://rari.app/fuse/pool/177
address constant fgohm = 0x720424E9cB93F46585C902512cC4DA2E8A06c86C;
address constant fusdc = 0xDE35E22Ac73d088BB9e7Cf29F306C008B3Dc8a21;
address constant feth  = 0x340d64fBf1EE1ffb3Fe022746fB97a598F3d92A9;

// ERC20 slots on Arbitrum to manipulate the token balance
uint256 constant wethSlot = 3;
uint256 constant usdcSlot = 9;
uint256 constant gohmSlot = 0;

// Sushiswap
address constant sushiRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
