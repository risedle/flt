// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;


/**
 * @title Uniswap V2 Pair Interface
 * @author bayu (github.com/pyk)
 */
interface IUniswapV2Pair {
    function token1() external view returns (address);
    function token0() external view returns (address);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}
