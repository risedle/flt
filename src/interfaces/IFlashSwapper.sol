// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

/**
 * @title Flash Swapper Interface
 * @author bayu (github.com/pyk)
 * @notice Contract that do flashswap via UniswapAdapter must implement this
 *         interface
 */
interface IFlashSwapper {
    function onFlashSwapExactTokensForTokensViaETH(uint256 _amountOut, bytes calldata _data) external;
}
