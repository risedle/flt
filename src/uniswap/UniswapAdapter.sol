// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUniswapV2Pair } from "../interfaces/IUniswapV2Pair.sol";
import { IUniswapV3Pool } from "../interfaces/IUniswapV3Pool.sol";
import { IFlashSwapper } from "../interfaces/IFlashSwapper.sol";

/**
 * @title Uniswap Adapter
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Simplify the interaction with Uniswap V2 (and its forks) and Uniswap V3
 */
contract UniswapAdapter is Ownable {

    /// ███ Storages ███████████████████████████████████████████████████████████

    /// @notice Pair/Pool of the TOKEN/ETH
    struct TokenMetadata {
        // Uniswap Version, 2 or 3
        uint8 version;
        // Uniswap V2 pair address
        IUniswapV2Pair pair;
        // Uniswap V3 pool address
        IUniswapV3Pool pool;
        // The router address
        address router;
    }

    /// @notice FlashSwapETHForExactTokens parameters
    struct FlashSwapETHForExactTokensParams {
        // ERC20 that received by this contract and sent to the flasher
        address tokenOut;
        // The flash swap caller
        address flasher;
        // The Uniswap Pair or Pool
        address pairOrPool;
        // The amount of tokenOut
        uint256 amountOut;
        // The amount of WETH that need to transfer to pair/pool address
        uint256 wethAmount;
    }

    /// @notice Mapping token to their TOKEN/ETH pair or pool address
    mapping(address => TokenMetadata) public tokens;

    /// @notice Flash swap types
    enum FlashSwapType { FlashSwapETHForExactTokens }


    /// ███ Events █████████████████████████████████████████████████████████████

    /// @notice Event emitted when metadata us updated
    event TokenMetadataUpdated(address token, uint8 version, address pairOrPool);

    /// @notice Event emitted when flash swap succeeded
    event FlashSwapped(uint8 uniswapVersion, address pairOrPool, address router, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);


    /// ███ Errors █████████████████████████████████████████████████████████████

    /// @notice Error is raised when owner use invalid uniswap version
    error InvalidUniswapVersion(uint8 version);

    /// @notice Error is raised when invalid amount
    error InvalidAmount(uint256 amount);

    /// @notice Error is raised when user trying to swap/flash swap token that doesn't have metadata
    error InvalidMetadata(address token);

    /// @notice Error is raised when the callback is called by unkown pair/pool
    error FlashSwapNotAuthorized();

    /// @notice Error is raised when the flasher failed to repay
    error FlashSwapRepayFailed();

    /// @notice Error is raised when this contract receive invalid amount when flashswap
    error FlashSwapReceivedAmountInvalid(uint256 expected, uint256 got);


    /// ███ Owner actions ██████████████████████████████████████████████████████

    /**
     * @notice setMetadata set metadata for TOKEN
     * @param _token The ERC20 token
     * @param _version The Uniswap version (2 or 3)
     * @param _pairOrPool The contract address of the TOKEN/ETH pair or pool
     * @param _router The Uniswap V2 or V3 router address
     */
    function setMetadata(address _token, uint8 _version, address _pairOrPool, address _router) external OnlyOwner {
        /// ███ Checks
        if (_version < 2 || _version > 3) revert InvalidUniswapVersion(_version);

        /// ███ Effects

        // Set metadata
        if (_version == 2) tokens[_token] = TokenMetadata({ version: _version, pair: IUniswapV2Pair(_pairOrPool), router: _router });
        if (_version == 3) tokens[_token] = TokenMetadata({ version: _version, pool: IUniswapV3Pool(_pairOrPool), router: _router });

        emit TokenMetadataUpdated(_token, _version, _pairOrPool);
    }


    /// ███ Internal functions █████████████████████████████████████████████████

    /// @notice Executed when flashSwapETHForExactTokens Uniswap V2 is triggered
    function onUniV2FlashSwapETHForExactTokens(FlashSwapETHForExactTokensParams _params, bytes memory _data) internal {
        /// Get the metadata
        TokenMetadata metadata = tokens[_params.tokenOut];

        // Transfer the token to flasher
        IERC20(_params.tokenOut).safeTransfer(_params.flasher, _params.amountOut);

        // Calculate the WETH amount
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = _params.tokenOut;
        _params.wethAmount = IUniswapV2Router(metadata.router).getAmountsIn(_params.amountOut, path)[0];

        // Execute the callback
        uint256 prevBalance = IERC20(_params.tokenOut).balanceOf(address(this));
        IFlashSwapper(_params.flasher).onFlashSwapETHForExactTokens(_params, _data);
        uint256 balance = IERC20(_params.tokenOut).balanceOf(address(this));

        // Check the balance
        if (balance < prevBalance + _params.wethAmount) revert FlashSwapRepayFailed();

        // Transfer the WETH to the pair or the pool
        IERC20(weth).safeTransfer(_params.pairOrPool, _amountIn);

        address pairOrPool = metadata.version == 2 ? metadata.pair : metadata.pool;
        emit FlashSwapped(metadata.version, pairOrPool, metadata.router, weth, _params.tokenOut, _params.wethAmount, _params.amountOut);
    }


    /// ███ Callbacks ██████████████████████████████████████████████████████████

    /// @notice Function is called by the Uniswap V2 pair's when swap function is executed
    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes memory _data) external {
        /// ███ Checks

        // Check caller
        if (tokens[msg.sender].version == 0) revert FlashSwapNotAuthorized();
        if (_sender != address(this)) revert FlashSwapNotAuthorized();

        // Get the data
        (FlashSwapType flashSwapType, bytes memory data) = abi.decode(_data, (FlashSwapType, bytes));

        // Continue execute the function based on the flash swap type
        if (flashSwapType == FlashSwapType.FlashSwapETHForExactTokens) {
            (FlashSwapETHForExactTokensParams params, bytes memory callData) = abi.decode(data, (FlashSwapETHForExactTokensParams,bytes));
            // Check the amount out
            uint256 amountOut = _amount0 == 0 ? _amount1 : _amount0;
            if (params.amountOut != amountOut) revert FlashSwapReceivedAmountInvalid(params.mountOut, amountOut);
            onUniV2FlashSwapETHForExactTokens(params, callData);
            return;
        }
    }


    /// ███ Adapters ███████████████████████████████████████████████████████████

    /**
     * @notice Borrow exact amount of tokenOut and repay it with WETH.
     *         The Uniswap Adapter will call msg.sender#onFlashSwapETHForExactTokens.
     * @param _tokenOut The address of ERC20 that swapped
     * @param _amountOut The exact amount of tokenOut that will be received by the caller
     */
    function flashSwapETHForExactTokens(address _tokenOut, uint256 _amountOut, bytes memory _data) external {
        /// ███ Checks
        if (_amountOut == 0) revert InvalidAmount(0);

        // Check the metadata
        TokenMetadata metadata = tokens[_tokenOut];
        if (metadata.version == 0) revert InvalidMetadata(_tokenOut);

        /// ███ Interactions

        // Flash swap Uniswap V2; The pair address will call uniswapV2Callback function
        if (metadata.version == 2) {
            // Get amountOut for token and weth
            uint256 amount0Out = _tokenOut == metadata.pair.token0() ? _amountOut : 0;
            uint256 amount1Out = _tokenOut == metadata.pair.token1() ? _amountOut : 0;

            // Do the flash swap
            FlashSwapETHForExactTokensParams params = FlashSwapETHForExactTokensParams({
                tokenOut: _tokenOut,
                amountOut: _amountOut,
                flasher: msg.sender,
                pairOrPool: metadata.pair
            });
            bytes memory data = abi.encode(FlashSwapType.FlashSwapETHForExactTokens, abi.encode(params, _data));
            metadata.pair.swap(amount0Out, amount1Out, address(this), data);

            return;
        }

        if (metadata.version == 3) {
            // zeroForOne (true: token0 -> token1) (false: token1 -> token0)
            bool zeroForOne = _tokenOut == metadata.pool.token1() ? true : false;

            // amountSpecified (Exact input: positive) (Exact output: negative)
            int256 amountSpecified = -1 * int256(_amountOut);
            uint160 sqrtPriceLimitX96 = (zeroForOne ? 4295128740 : 1461446703485210103287273052203988822378723970341);

            // Perform swap
            bytes memory data = abi.encode(FlashSwapType.FlashSwapETHForExactTokens, abi.encode("test"));
            pool.swap(address(this), zeroForOne, amountSpecified, sqrtPriceLimitX96, data);
            return;
        }
    }
}