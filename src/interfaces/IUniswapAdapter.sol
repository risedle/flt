// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

/**
 * @title Uniswap Adapter Interface
 * @author bayu (github.com/pyk)
 * @notice One interface to interact with Uniswap V2 and Uniswap V3
 */
interface IUniswapAdapter {
    function isConfigured(address _token) external view returns (bool);
    function flashSwapWETHForExactTokens(address _tokenOut, uint256 _amountOut, bytes memory _data) external;
    function swapExactTokensForWETH(address _tokenIn, uint256 _amountIn, uint256 _amountOutMin) external returns (uint256 _amountOut);
    function swapExactWETHForTokens(address _tokenOut, uint256 _wethAmount, uint256 _amountOutMin) external returns (uint256 _amountOut);
    function swapTokensForExactWETH(address _tokenIn, uint256 _amountIn, uint256 _amountOutMin) external returns (uint256 _amountOut);
    function previewSwapWETHForExactTokens(address _tokenOut, uint256 _amountOut) external view returns (uint256 _wethAmount);
    function previewSwapTokensForExactWETH(address _tokenIn, uint256 _wethAmount) external view returns (uint256 _amountIn);
    function previewSwapExactTokensForWETH(address _tokenIn, uint256 _amountIn) external view returns (uint256 _wethAmount);
    function previewSwapExactWETHForTokens(address _tokenOut, uint256 _wethAmount) external view returns (uint256 _amountOut);
    function weth() external view returns (address);
}
