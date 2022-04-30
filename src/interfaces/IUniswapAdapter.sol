// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;


import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import { IUniswapV2Pair } from "../interfaces/IUniswapV2Pair.sol";
import { IUniswapV3Pool } from "../interfaces/IUniswapV3Pool.sol";
import { IUniswapAdapterCaller } from "../interfaces/IUniswapAdapterCaller.sol";

/**
 * @title Uniswap Adapter
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Utility contract to interact with Uniswap V2 & V3
 */
interface IUniswapAdapter {

    /// ███ Types ██████████████████████████████████████████████████████████████

    /**
     * @notice The supported Uniswap version
     */
    enum UniswapVersion {
        UniswapV2,
        UniswapV3
    }

    /**
     * @notice Liquidity data for specified token
     * @param version The address of Rise Token
     * @param pair The Uniswap V2 pair address
     * @param pool The Uniswap V3 pool address
     * @param router The Uniswap router address
     */
    struct LiquidityData {
        UniswapVersion version;
        IUniswapV2Pair pair;
        IUniswapV3Pool pool;
        address router;
    }

    /**
     * @notice Parameters to do flash swap WETH->tokenOut
     * @param tokenOut The output token
     * @param caller The flash swap caller
     * @param liquidityData Liquidi
     * @param amountOut The amount of tokenOut that will be received by
     *        this contract
     * @param wethAmount The amount of WETH required to finish the flash swap
     */
    struct FlashSwapWETHForExactTokensParams {
        IERC20 tokenOut;
        IUniswapAdapterCaller caller;
        LiquidityData liquidityData;
        uint256 amountOut;
        uint256 wethAmount;
    }

    /// @notice Flash swap types
    enum FlashSwapType {
        FlashSwapWETHForExactTokens
    }


    /// ███ Events █████████████████████████████████████████████████████████████

    /**
     * @notice Event emitted when token is configured
     * @param liquidityData The liquidity data of the token
     */
    event TokenConfigured(LiquidityData liquidityData);

    /**
     * @notice Event emitted when flash swap succeeded
     * @param params The flash swap params
     */
    event FlashSwapped(FlashSwapWETHForExactTokensParams params);


    /// ███ Errors █████████████████████████████████████████████████████████████

    /// @notice Error is raised when owner use invalid uniswap version
    error InvalidUniswapVersion(uint8 version);

    /// @notice Error is raised when invalid amount
    error InvalidAmount(uint256 amount);

    /// @notice Error is raised when token is not configured
    error TokenNotConfigured(address token);

    /// @notice Error is raised when the callback is called by unkown pair/pool
    error CallerNotAuthorized();

    /// @notice Error is raised when the caller not repay the token
    error CallerNotRepay();

    /// @notice Error is raised when this contract receive invalid amount when flashswap
    error FlashSwapReceivedAmountInvalid(uint256 expected, uint256 got);


    /// ███ Owner actions ██████████████████████████████████████████████████████

    /**
     * @notice Configure the token
     * @param _token The ERC20 token
     * @param _version The Uniswap version (2 or 3)
     * @param _pairOrPool The contract address of the TOKEN/ETH pair or pool
     * @param _router The Uniswap V2 or V3 router address
     */
    function configure(
        address _token,
        UniswapVersion _version,
        address _pairOrPool,
        address _router
    ) external;


    /// ███ Read-only functions ████████████████████████████████████████████████

    /**
     * @notice Returns true if token is configured
     * @param _token The token address
     */
    function isConfigured(address _token) external view returns (bool);

    /// ███ Adapters ███████████████████████████████████████████████████████████

    /**
     * @notice Borrow exact amount of tokenOut and repay it with WETH.
     *         The Uniswap Adapter will call msg.sender#onFlashSwapWETHForExactTokens.
     * @param _tokenOut The address of ERC20 that swapped
     * @param _amountOut The exact amount of tokenOut that will be received by the caller
     */
    function flashSwapWETHForExactTokens(
        address _tokenOut,
        uint256 _amountOut,
        bytes memory _data
    ) external;

    /**
     * @notice Swaps an exact amount of input tokenIn for as many WETH as possible
     * @param _tokenIn tokenIn address
     * @param _amountIn The amount of tokenIn
     * @param _amountOutMin The minimum amount of WETH to be received
     * @return _amountOut The WETH amount received
     */
    function swapExactTokensForWETH(
        address _tokenIn,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external returns (uint256 _amountOut);

    /**
     * @notice Swaps an exact amount of WETH for as few tokenIn as possible.
     * @param _tokenIn tokenIn address
     * @param _wethAmount The amount of tokenIn
     * @param _amountInMax The minimum amount of WETH to be received
     * @return _amountIn The WETH amount received
     */
    function swapTokensForExactWETH(
        address _tokenIn,
        uint256 _wethAmount,
        uint256 _amountInMax
    ) external returns (uint256 _amountIn);

    /**
     * @notice Swaps an exact amount of WETH for tokenOut
     * @param _tokenOut tokenOut address
     * @param _wethAmount The amount of WETH
     * @param _amountOutMin The minimum amount of WETH to be received
     * @return _amountOut The WETH amount received
     */
    function swapExactWETHForTokens(
        address _tokenOut,
        uint256 _wethAmount,
        uint256 _amountOutMin
    ) external returns (uint256 _amountOut);

}
