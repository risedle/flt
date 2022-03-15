// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

interface IUniswapV2Pair {
    function token1() external view returns (address);
    function token0() external view returns (address);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}
