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
    function getAmountOutViaETH(address[2] memory _tokens, uint256 _amountIn) external view returns (uint256 _amountOut);
    function getAmountInViaETH(address[2] memory _tokens, uint256 _amountOut) external view returns (uint256 _amountIn);
    function swapTokensForExactTokensViaETH(uint256 _amountOut, uint256 _amountInMax, address[2] calldata _tokens) external returns (uint256 _amountIn);
}
