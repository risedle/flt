// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

// ERC20 addresses on Ethereum
address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant gohm = 0x0ab87046fBb341D058F17CBC4c1133F25a20a52f;
address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

// fToken on Risedle Fuse Pools
// https://rari.app/fuse/pool/177
address constant fgohm = 0x720424E9cB93F46585C902512cC4DA2E8A06c86C;
address constant fusdc = 0xDE35E22Ac73d088BB9e7Cf29F306C008B3Dc8a21;
address constant feth  = 0x340d64fBf1EE1ffb3Fe022746fB97a598F3d92A9;

// ERC20 slots on Arbitrum to manipulate the token balance
uint256 constant wethSlot = 3;
uint256 constant usdcSlot = 9;
uint256 constant gohmSlot = 0;
uint256 constant wbtcSlot = 0;

// Uniswap Routers, Pools and Pairs
address constant uniswapV2Router      = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
address constant uniswapV3Router      = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
address constant uniswapV3WBTCETHPool = 0xCBCdF9626bC03E24f779434178A73a0B4bad62eD;
address constant sushiRouter          = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
address constant sushiWBTCETHPair     = 0xCEfF51756c56CeFFCA006cD410B03FFC46dd3a58;