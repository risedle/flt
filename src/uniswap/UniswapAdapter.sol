// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUniswapV2Router02 } from "../interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "../interfaces/IUniswapV2Pair.sol";
import { IUniswapV3Pool } from "../interfaces/IUniswapV3Pool.sol";
import { IUniswapAdapterCaller } from "../interfaces/IUniswapAdapterCaller.sol";

/**
 * @title Uniswap Adapter
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Simplify the interaction with Uniswap V2 (and its forks) and Uniswap V3
 */
contract UniswapAdapter is Ownable {
    /// ███ Libraries ██████████████████████████████████████████████████████████

    using SafeERC20 for IERC20;

    /// ███ Storages ███████████████████████████████████████████████████████████

    /// @notice WETH address
    IERC20 public weth;

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
        // ERC20 that received by this contract and sent to the caller
        IERC20 tokenOut;
        // The flash swap caller
        IUniswapAdapterCaller caller;
        // The Uniswap Pair or Pool
        TokenMetadata metadata;
        // The amount of tokenOut
        uint256 amountOut;
        // The amount of WETH that need to transfer to pair/pool address
        uint256 wethAmount;
    }

    /// @notice Mapping token to their TOKEN/ETH pair or pool address
    mapping(address => TokenMetadata) public tokens;

    /// @notice Flash swap types
    enum FlashSwapType { FlashSwapETHForExactTokens }

    /// @notice Whitelisted pair/pool that can call the callback
    mapping(address => bool) private isValidCallbackCaller;


    /// ███ Events █████████████████████████████████████████████████████████████

    /// @notice Event emitted when metadata us updated
    event TokenMetadataUpdated(address token, uint8 version, address pairOrPool);

    /// @notice Event emitted when flash swap succeeded
    event FlashSwapped(FlashSwapETHForExactTokensParams params);


    /// ███ Errors █████████████████████████████████████████████████████████████

    /// @notice Error is raised when owner use invalid uniswap version
    error InvalidUniswapVersion(uint8 version);

    /// @notice Error is raised when invalid amount
    error InvalidAmount(uint256 amount);

    /// @notice Error is raised when user trying to swap/flash swap token that doesn't have metadata
    error InvalidMetadata(address token);

    /// @notice Error is raised when the callback is called by unkown pair/pool
    error CallerNotAuthorized();

    /// @notice Error is raised when the caller not repay the token
    error CallerNotRepay();

    /// @notice Error is raised when this contract receive invalid amount when flashswap
    error FlashSwapReceivedAmountInvalid(uint256 expected, uint256 got);


    /// ███ Constuctors ████████████████████████████████████████████████████████

    constructor(address _weth) {
        weth = IERC20(_weth);
    }


    /// ███ Owner actions ██████████████████████████████████████████████████████

    /**
     * @notice setMetadata set metadata for TOKEN
     * @param _token The ERC20 token
     * @param _version The Uniswap version (2 or 3)
     * @param _pairOrPool The contract address of the TOKEN/ETH pair or pool
     * @param _router The Uniswap V2 or V3 router address
     */
    function setMetadata(address _token, uint8 _version, address _pairOrPool, address _router) external onlyOwner {
        /// ███ Checks
        if (_version < 2 || _version > 3) revert InvalidUniswapVersion(_version);

        /// ███ Effects

        // Set metadata
        isValidCallbackCaller[_pairOrPool] = true;
        tokens[_token] = TokenMetadata({ version: _version, pool: IUniswapV3Pool(_pairOrPool), pair: IUniswapV2Pair(_pairOrPool), router: _router });

        emit TokenMetadataUpdated(_token, _version, _pairOrPool);
    }


    /// ███ Internal functions █████████████████████████████████████████████████

    /// @notice Executed when flashSwapETHForExactTokens Uniswap V2 is triggered
    function onUniV2FlashSwapETHForExactTokens(FlashSwapETHForExactTokensParams memory _params, bytes memory _data) internal {
        // Transfer the tokenOut to caller
        _params.tokenOut.safeTransfer(address(_params.caller), _params.amountOut);

        // Calculate the WETH amount
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(_params.tokenOut);
        _params.wethAmount = IUniswapV2Router02(_params.metadata.router).getAmountsIn(_params.amountOut, path)[0];

        // Execute the callback
        uint256 prevBalance = weth.balanceOf(address(this));
        _params.caller.onFlashSwapETHForExactTokens(_params.wethAmount, _params.amountOut, _data);
        uint256 balance = weth.balanceOf(address(this));

        // Check the balance
        if (balance < prevBalance + _params.wethAmount) revert CallerNotRepay();

        // Transfer the WETH to the Uniswap V2 pair
        weth.safeTransfer(address(_params.metadata.pair), _params.wethAmount);

        emit FlashSwapped(_params);
    }


    /// ███ Callbacks ██████████████████████████████████████████████████████████

    /// @notice Function is called by the Uniswap V2 pair's when swap function is executed
    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes memory _data) external {
        /// ███ Checks

        // Check caller
        if (!isValidCallbackCaller[msg.sender]) revert CallerNotAuthorized();
        if (_sender != address(this)) revert CallerNotAuthorized();

        // Get the data
        (FlashSwapType flashSwapType, bytes memory data) = abi.decode(_data, (FlashSwapType, bytes));

        // Continue execute the function based on the flash swap type
        if (flashSwapType == FlashSwapType.FlashSwapETHForExactTokens) {
            (FlashSwapETHForExactTokensParams memory params, bytes memory callData) = abi.decode(data, (FlashSwapETHForExactTokensParams,bytes));
            // Check the amount out
            uint256 amountOut = _amount0 == 0 ? _amount1 : _amount0;
            if (params.amountOut != amountOut) revert FlashSwapReceivedAmountInvalid(params.amountOut, amountOut);
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
        TokenMetadata memory metadata = tokens[_tokenOut];
        if (metadata.version == 0) revert InvalidMetadata(_tokenOut);

        /// ███ Interactions

        // Flash swap Uniswap V2; The pair address will call uniswapV2Callback function
        if (metadata.version == 2) {
            // Get amountOut for token and weth
            uint256 amount0Out = _tokenOut == metadata.pair.token0() ? _amountOut : 0;
            uint256 amount1Out = _tokenOut == metadata.pair.token1() ? _amountOut : 0;

            // Do the flash swap
            FlashSwapETHForExactTokensParams memory params = FlashSwapETHForExactTokensParams({
                tokenOut: IERC20(_tokenOut),
                amountOut: _amountOut,
                caller: IUniswapAdapterCaller(msg.sender),
                metadata: metadata,
                wethAmount: 0 // Initialize as zero; It will be updated in the callback
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
            metadata.pool.swap(address(this), zeroForOne, amountSpecified, sqrtPriceLimitX96, data);
            return;
        }
    }
}