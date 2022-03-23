// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

/**
 * @title Uniswap Adapter Interface
 * @author bayu (github.com/pyk)
 * @notice One interface to interact with Uniswap V2 and Uniswap V3
 */
interface IUniswapAdapter {
    function flashSwapExactTokensForTokensViaETH(uint256 _amountIn, uint256 _amountOutMin, address[2] calldata _tokens, bytes calldata _data) external;
}
