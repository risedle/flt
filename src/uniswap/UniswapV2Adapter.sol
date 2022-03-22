// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUniswapV2Router02 } from "../interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Factory } from "../interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Pair } from "../interfaces/IUniswapV2Pair.sol";
import { IFlashSwapper } from "../interfaces/IFlashSwapper.sol";

/**
 * @title Uniswap V2 Adapter
 * @author bayu (github.com/pyk)
 * @notice Standarize Uniswap V2 interaction (swap & flashswap) as IUniswapAdapter
 */
contract UniswapV2Adapter {
    /// ███ Libraries ██████████████████████████████████████████████████████████

    using SafeERC20 for IERC20;


    /// ███ Storages ███████████████████████████████████████████████████████████

    /// @notice Uniswap V2 router address
    address public immutable router;

    /// @notice WETH address
    address public immutable weth;

    /// @notice The flashswap types
    enum FlashSwapType {FlashSwapExactTokensForTokensViaETH}


    /// ███ Errors █████████████████████████████████████████████████████████████

    error FlashSwapAmountCannotBeZero();
    error FlashSwapPairNotFound(address token0, address token1);
    error FlashSwapNotAuthorized();

    /// @notice Error is raised when flash swap amount out is too low
    error FlashSwapAmountOutTooLow(uint256 min, uint256 got);


    /// ███ Constuctors ████████████████████████████████████████████████████████

    constructor(address _router) {
        router = _router;
        weth = IUniswapV2Router02(_router).WETH();
    }

    /// ███ Internal functions █████████████████████████████████████████████████

    function onFlashSwapExactTokensForTokensViaETH(uint256 _wethAmount, uint256 _amountIn, uint256 _amountOut, address[2] memory _tokens, address _flasher, bytes memory _data) internal {
        /// ███ Checks

        // Check pairs
        address tokenInPair = IUniswapV2Factory(IUniswapV2Router02(router).factory()).getPair(_tokens[0], weth);
        address tokenOutPair = IUniswapV2Factory(IUniswapV2Router02(router).factory()).getPair(_tokens[1], weth);
        if (tokenInPair == address(0)) revert FlashSwapPairNotFound(_tokens[0], weth);
        if (tokenOutPair == address(0)) revert FlashSwapPairNotFound(_tokens[1], weth);

        // Step 4:
        // Swap WETH to tokenOut
        address token0 = IUniswapV2Pair(tokenOutPair).token0();
        address token1 = IUniswapV2Pair(tokenOutPair).token1();
        uint256 amount0Out = _tokens[1] == token0 ? _amountOut : 0;
        uint256 amount1Out = _tokens[1] == token1 ? _amountOut : 0;
        IERC20(weth).safeTransfer(tokenOutPair, _wethAmount);
        IUniswapV2Pair(tokenOutPair).swap(amount0Out, amount1Out, address(this), bytes(""));

        // Step 5:
        // Transfer tokenOut to flasher
        IERC20(_tokens[1]).safeTransfer(_flasher, _amountOut);

        // Step 6:
        // Call the flasher
        IFlashSwapper(_flasher).onFlashSwapExactTokensForTokensViaETH(_amountOut, _data);

        // Step 8:
        // Repay the flashswap
        IERC20(_tokens[0]).safeTransfer(tokenInPair, _amountIn);

    }

    function getAmountOutViaETH(address[2] memory _tokens, uint256 _amountIn) internal returns (uint256 _amountOut) {
        address[] memory tokenInToTokenOut = new address[](3);
        tokenInToTokenOut[0] = _tokens[0];
        tokenInToTokenOut[1] = weth;
        tokenInToTokenOut[3] = _tokens[1];
        _amountOut = IUniswapV2Router02(router).getAmountsOut(_amountIn, tokenInToTokenOut)[2];
    }


    /// ███ Callbacks ██████████████████████████████████████████████████████████

    /// @notice Function is called by the Uniswap V2 pair's when swap function is executed
    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes memory _data) external {
        /// ███ Checks

        // Check caller
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        if (msg.sender != IUniswapV2Factory(IUniswapV2Router02(router).factory()).getPair(token0, token1)) revert FlashSwapNotAuthorized();
        if (_sender != address(this)) revert FlashSwapNotAuthorized();

        // Get the data
        (FlashSwapType flashSwapType, bytes memory data) = abi.decode(_data, (FlashSwapType, bytes));

        // Continue execute the function based on the flash swap type
        if (flashSwapType == FlashSwapType.FlashSwapExactTokensForTokensViaETH) {
            // Get WETH amount
            uint256 wethAmount = _amount0 == 0 ? _amount1 : _amount0;
            (uint256 amountIn, uint256 amountOut, address tokenIn, address tokenOut, address flasher, bytes memory callData) = abi.decode(data, (uint256,uint256,address,address,address,bytes));
            onFlashSwapExactTokensForTokensViaETH(wethAmount, amountIn, amountOut, [tokenIn, tokenOut], flasher, callData);
            return;
        }
    }

    /// ███ Adapters ███████████████████████████████████████████████████████████

    /**
     * @notice Flash swaps an exact amount of input tokens for as many output
     *         tokens as possible via tokenIn/WETH and tokenOut/WETH pairs.
     * @param _amountIn The amount of tokenIn that used to repay the flash swap
     * @param _amountOutMin The minimum amount of tokenOut that will received by the flash swap executor
     * @param _tokens _tokens[0] is the tokenIn and _tokens[1] is the tokenOut
     * @param _data Bytes data transfered to callback
     */
    function flashSwapExactTokensForTokensViaETH(uint256 _amountIn, uint256 _amountOutMin, address[2] calldata _tokens, bytes calldata _data) public {
        /// ███ Checks

        // Check amount
        if (_amountIn == 0) revert FlashSwapAmountCannotBeZero();

        // Check pairs
        address tokenInPair = IUniswapV2Factory(IUniswapV2Router02(router).factory()).getPair(_tokens[0], weth);
        if (tokenInPair == address(0)) revert FlashSwapPairNotFound(_tokens[0], weth);

        // Check the amount of tokenOut
        uint256 amountOut = getAmountOutViaETH(_tokens, _amountIn);
        if (amountOut > _amountOutMin) revert FlashSwapAmountOutTooLow(_amountOutMin, amountOut);

        /// ███ Effects

        /// ███ Interactions

        // Step 1:
        // Calculate how much WETH we need to borrow from tokenIn/WETH pair
        address[] memory wethToTokenOut = new address[](2);
        wethToTokenOut[0] = weth;
        wethToTokenOut[1] = _tokens[1];
        uint256 wethAmount = IUniswapV2Router02(router).getAmountsIn(amountOut, wethToTokenOut)[0];

        // Step 2:
        // Borrow WETH from tokenIn/WETH liquidity pair (e.g. USDC/WETH)
        uint256 amount0Out = weth == IUniswapV2Pair(tokenInPair).token0() ? wethAmount : 0;
        uint256 amount1Out = weth == IUniswapV2Pair(tokenInPair).token1() ? wethAmount : 0;

        // Step 3:
        // Perform the flashswap to Uniswap V2; Step 4 in onFlashSwapExactTokensForTokensViaETH
        bytes memory data = abi.encode(FlashSwapType.FlashSwapExactTokensForTokensViaETH, abi.encode(_amountIn, amountOut, _tokens[0], _tokens[1], msg.sender, _data));
        IUniswapV2Pair(tokenInPair).swap(amount0Out, amount1Out, address(this), data);

    }
}
