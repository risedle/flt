// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

/**
 * @title Uniswap Adapter Interface
 * @author bayu (github.com/pyk)
 * @notice One interface to interact with Uniswap V2 and Uniswap V3
 */
interface IUniswapAdapter {
    function isConfigured(address _token) external returns (bool);
    function flashSwapETHForExactTokens(address _tokenOut, uint256 _amountOut, bytes memory _data) external;
    function swapExactTokensForWETH(address _tokenIn, uint256 _amountIn, uint256 _amountOutMin) external returns (uint256 _amountOut);
}
