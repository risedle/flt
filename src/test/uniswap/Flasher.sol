// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUniswapAdapter } from "../../interfaces/IUniswapAdapter.sol";

/**
 * @title Flasher
 * @author bayu (github.com/pyk)
 * @notice Contract to simulate the flash swap user of UniswapV2Adapter.
 *         This contract implements IFlashSwapper.
 */
contract Flasher {
    /// ███ Libraries ██████████████████████████████████████████████████████████
    using SafeERC20 for IERC20;


    /// ███ Storages ███████████████████████████████████████████████████████████

    /// @notice Uniswap V2 Adapter
    address private uniswapAdapter;

    /// @notice The tokenIn
    address private tokenIn;

    /// @notice The tokenOut
    address private tokenOut;

    /// @notice The amount of tokenIn
    uint256 private amountIn;


    /// ███ Events █████████████████████████████████████████████████████████████

    event FlashSwap(uint256 amount, bytes data);


    /// ███ Errors █████████████████████████████████████████████████████████████

    /// @notice Error raised when onFlashSwap caller is not the UniswapAdapter
    error NotUniswapAdapter();


    /// ███ Constructors ███████████████████████████████████████████████████████

    constructor(address _uniswapAdapter) {
        uniswapAdapter = _uniswapAdapter;
    }


    /// ███ External functions █████████████████████████████████████████████████

    /// @notice Trigger the flash swap
    function flashSwapExactTokensForTokensViaETH(uint256 _amountIn, uint256 _amountOutMin, address[2] calldata _tokens, bytes calldata _data) external {
        tokenIn = _tokens[0];
        tokenOut = _tokens[1];
        amountIn = _amountIn;
        IUniswapAdapter(uniswapAdapter).flashSwapExactTokensForTokensViaETH(_amountIn, _amountOutMin, _tokens, _data);
    }

    /// @notice Executed by the adapter
    function onFlashSwapExactTokensForTokensViaETH(uint256 _amountOut, bytes calldata _data) external {
        /// ███ Checks

        // Check the caller; Make sure it's Uniswap Adapter
        if (msg.sender != uniswapAdapter) revert NotUniswapAdapter();

        /// ███ Effects

        /// ███ Interactions

        IERC20(tokenIn).safeTransfer(uniswapAdapter, amountIn);

        emit FlashSwap(_amountOut, _data);
    }
}
