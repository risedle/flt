// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;


/**
 * @title Uniswap V2 Factory Interface
 * @author bayu (github.com/pyk)
 */
interface IUniswapV2Factory {
  function getPair(address tokenA, address tokenB) external view returns (address pair);
}
