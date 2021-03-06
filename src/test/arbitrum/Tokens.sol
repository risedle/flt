// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;


// ERC20 addresses on Arbitrum
address constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
address constant gohm = 0x8D9bA570D6cb60C7e3e0F31343Efe75AB8E65FB1;
address constant usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
address constant wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

// Rari Fuse
address constant fgohm = 0xd861026A12623aec769fA57D05201193D8844368;
address constant fusdc = 0x156157693BA371c5B126AAeF784D2853EbC8fEFa;
address constant fwbtc = 0xC890044a3e44cbb98fC12C87012a5e50E7A3aD3d;

// Rari Fuse Price Oracles
address constant rariFuseGOHMPriceOracle = 0x5dA877E48662d14379C6F425f1de8E69Ad01C527;
address constant rariFuseUSDCPriceOracle = 0x5dA877E48662d14379C6F425f1de8E69Ad01C527;
address constant rariFuseWBTCPriceOracle = 0x5dA877E48662d14379C6F425f1de8E69Ad01C527;

// ERC20 slots on Arbitrum to manipulate the token balance
uint256 constant usdcSlot = 51;
uint256 constant gohmSlot = 101;
uint256 constant wethSlot = 51;
uint256 constant wbtcSlot = 51;

// Uniswap Routers, Pools and Pairs
address constant uniswapV2Router      = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506; // Use SushiSwap as Univ2 on arbitrum
address constant uniswapV3Router      = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
address constant uniswapV3WBTCETHPool = 0x149e36E72726e0BceA5c59d40df2c43F60f5A22D;
address constant uniswapV3USDCETHPool = 0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443;
address constant sushiRouter          = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;
address constant sushiWBTCETHPair     = 0x515e252b2b5c22b4b2b6Df66c2eBeeA871AA4d69;
