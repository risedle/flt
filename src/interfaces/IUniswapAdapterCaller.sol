// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

/**
 * @title Uniswap Adapter Caller Interface
 * @author bayu (github.com/pyk)
 * @notice Contract that interact with Uniswap Adapter should implement this interface.
 */
interface IUniswapAdapterCaller {
    /**
     * @notice Function that will be executed by Uniswap Adapter to finish the flash swap.
     *         The caller will receive _amountOut of the specified tokenOut.
     * @param _wethAmount The amount of WETH that the caller need to send back to the Uniswap Adapter
     * @param _amountOut The amount of of tokenOut transfered to the caller.
     * @param _data Data passed by the caller.
     */
    function onFlashSwapWETHForExactTokens(uint256 _wethAmount, uint256 _amountOut, bytes calldata _data) external;
}
