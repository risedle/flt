// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { Ownable } from "openzeppelin/access/Ownable.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { SafeERC20 } from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import { IUniswapAdapter } from "../interfaces/IUniswapAdapter.sol";
import { IUniswapV2Router02 } from "../interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "../interfaces/IUniswapV2Pair.sol";
import { IUniswapV3Pool } from "../interfaces/IUniswapV3Pool.sol";
import { IUniswapV3SwapRouter } from "../interfaces/IUniswapV3SwapRouter.sol";
import { IUniswapAdapterCaller } from "../interfaces/IUniswapAdapterCaller.sol";

import { IWETH9 } from "../interfaces/IWETH9.sol";

/**
 * @title Uniswap Adapter
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Utility contract to interact with Uniswap V2 & V3
 */
contract UniswapAdapter is IUniswapAdapter, Ownable {

    /// ███ Libraries ████████████████████████████████████████████████████████

    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH9;

    /// ███ Storages █████████████████████████████████████████████████████████

    /// @notice WETH address
    IWETH9 public weth;

    /// @notice Mapping token to their liquidity metadata
    mapping(address => LiquidityData) public liquidities;

    /// @notice Whitelisted pair/pool that can call the callback
    mapping(address => bool) private isValidCallbackCaller;


    /// ███ Constuctor ███████████████████████████████████████████████████████

    constructor(address _weth) {
        weth = IWETH9(_weth);
    }


    /// ███ Owner actions ████████████████████████████████████████████████████

    /// @inheritdoc IUniswapAdapter
    function configure(
        address _token,
        UniswapVersion _version,
        address _pairOrPool,
        address _router
    ) external onlyOwner {
        isValidCallbackCaller[_pairOrPool] = true;
        liquidities[_token] = LiquidityData({
            version: _version,
            pool: IUniswapV3Pool(_pairOrPool),
            pair: IUniswapV2Pair(_pairOrPool),
            router: _router
        });
        emit TokenConfigured(liquidities[_token]);
    }


    /// ███ Internal functions ███████████████████████████████████████████████

    /// @notice Executed when flashSwapWETHForExactTokens is triggered
    function onFlashSwapWETHForExactTokens(
        FlashSwapWETHForExactTokensParams memory _params,
        bytes memory _data
    ) internal {
        // Transfer the tokenOut to caller
        _params.tokenOut.safeTransfer(
            address(_params.caller),
            _params.amountOut
        );

        // Execute the callback
        uint256 prevBalance = weth.balanceOf(address(this));
        _params.caller.onFlashSwapWETHForExactTokens(
            _params.wethAmount,
            _params.amountOut,
            _data
        );
        uint256 balance = weth.balanceOf(address(this));

        // Check the balance
        if (balance < prevBalance + _params.wethAmount) revert CallerNotRepay();

        // Transfer the WETH to the Uniswap V2 pair or pool
        if (_params.liquidityData.version == UniswapVersion.UniswapV2) {
            weth.safeTransfer(
                address(_params.liquidityData.pair),
                _params.wethAmount
            );
        } else {
            weth.safeTransfer(
                address(_params.liquidityData.pool),
                _params.wethAmount
            );
        }

        emit FlashSwapped(_params);
    }


    /// ███ Callbacks ████████████████████████████████████████████████████████

    function uniswapV2Call(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes memory _data
    ) external {
        /// ███ Checks

        // Check caller
        if (!isValidCallbackCaller[msg.sender]) revert CallerNotAuthorized();
        if (_sender != address(this)) revert CallerNotAuthorized();

        /// ███ Interactions

        // Get the data
        (FlashSwapType flashSwapType, bytes memory data) = abi.decode(
            _data,
            (FlashSwapType, bytes)
        );

        // Continue execute the function based on the flash swap type
        if (flashSwapType == FlashSwapType.FlashSwapWETHForExactTokens) {
            (
                FlashSwapWETHForExactTokensParams memory params,
                bytes memory callData
            ) = abi.decode(data, (FlashSwapWETHForExactTokensParams,bytes));

            // Check the amount out
            uint256 amountOut = _amount0 == 0 ? _amount1 : _amount0;
            if (params.amountOut != amountOut)  {
                revert FlashSwapReceivedAmountInvalid(
                    params.amountOut,
                    amountOut
                );
            }

            // Calculate the WETH amount
            address[] memory path = new address[](2);
            path[0] = address(weth);
            path[1] = address(params.tokenOut);
            IUniswapV2Router02 router = IUniswapV2Router02(params.liquidityData.router);
            params.wethAmount = router.getAmountsIn(params.amountOut, path)[0];

            onFlashSwapWETHForExactTokens(params, callData);
            return;
        }
    }

    function uniswapV3SwapCallback(
        int256 _amount0Delta,
        int256 _amount1Delta,
        bytes memory _data
    ) external {
        /// ███ Checks

        // Check caller
        if (!isValidCallbackCaller[msg.sender]) revert CallerNotAuthorized();

        /// ███ Interactions

        // Get the data
        (
            FlashSwapType flashSwapType,
            bytes memory data
        ) = abi.decode(_data, (FlashSwapType, bytes));

        // Continue execute the function based on the flash swap type
        if (flashSwapType == FlashSwapType.FlashSwapWETHForExactTokens) {
            (
                FlashSwapWETHForExactTokensParams memory params,
                bytes memory callData
            ) = abi.decode(data, (FlashSwapWETHForExactTokensParams,bytes));

            // if amount negative then it must be the amountOut,
            // otherwise it's weth amount
            uint256 amountOut;
            if (_amount0Delta < 0) {
                amountOut = uint256(-1 * _amount0Delta);
                params.wethAmount = uint256(_amount1Delta);
            } else {
                amountOut = uint256(-1 * _amount1Delta);
                params.wethAmount = uint256(_amount0Delta);
            }

            // Check the amount out
            if (params.amountOut != amountOut) {
                revert FlashSwapReceivedAmountInvalid(
                    params.amountOut,
                    amountOut
                );
            }

            onFlashSwapWETHForExactTokens(params, callData);
            return;
        }
    }


    /// ███ Read-only functions ██████████████████████████████████████████████

    /// @inheritdoc IUniswapAdapter
    function isConfigured(address _token) public view returns (bool) {
        if (liquidities[_token].router == address(0)) return false;
        return true;
    }


    /// ███ Adapters █████████████████████████████████████████████████████████

    /// @inheritdoc IUniswapAdapter
    function flashSwapWETHForExactTokens(
        address _tokenOut,
        uint256 _amountOut,
        bytes memory _data
    ) external {
        /// ███ Checks
        if (_amountOut == 0) revert InvalidAmount(0);
        if (!isConfigured(_tokenOut)) revert TokenNotConfigured(_tokenOut);

        // Check the metadata
        LiquidityData memory metadata = liquidities[_tokenOut];

        /// ███ Interactions

        // Initialize the params
        FlashSwapWETHForExactTokensParams memory params = FlashSwapWETHForExactTokensParams({
            tokenOut: IERC20(_tokenOut),
            amountOut: _amountOut,
            caller: IUniswapAdapterCaller(msg.sender),
            liquidityData: metadata,
            wethAmount: 0 // Initialize as zero; It will be updated in the callback
        });
        bytes memory data = abi.encode(
            FlashSwapType.FlashSwapWETHForExactTokens,
            abi.encode(params, _data)
        );

        // Flash swap Uniswap V2; The pair address will call uniswapV2Callback function
        if (metadata.version == UniswapVersion.UniswapV2) {
            // Get amountOut for token and weth
            uint256 amount0Out = _tokenOut == metadata.pair.token0() ? _amountOut : 0;
            uint256 amount1Out = _tokenOut == metadata.pair.token1() ? _amountOut : 0;

            // Do the flash swap
            metadata.pair.swap(amount0Out, amount1Out, address(this), data);
            return;
        }

        if (metadata.version == UniswapVersion.UniswapV3) {
            // zeroForOne (true: token0 -> token1) (false: token1 -> token0)
            bool zeroForOne = _tokenOut == metadata.pool.token1() ? true : false;

            // amountSpecified (Exact input: positive) (Exact output: negative)
            int256 amountSpecified = -1 * int256(_amountOut);
            uint160 sqrtPriceLimitX96 = (zeroForOne ? 4295128740 : 1461446703485210103287273052203988822378723970341);

            // Perform swap
            metadata.pool.swap(
                address(this),
                zeroForOne,
                amountSpecified,
                sqrtPriceLimitX96,
                data
            );
            return;
        }
    }

    /// @inheritdoc IUniswapAdapter
    function swapExactTokensForWETH(
        address _tokenIn,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external returns (uint256 _amountOut) {
        /// ███ Checks
        if (!isConfigured(_tokenIn)) revert TokenNotConfigured(_tokenIn);

        /// ███ Interactions
        LiquidityData memory metadata = liquidities[_tokenIn];
        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
        IERC20(_tokenIn).safeIncreaseAllowance(metadata.router, _amountIn);

        if (metadata.version == UniswapVersion.UniswapV2) {
            // Do the swap
            address[] memory path = new address[](2);
            path[0] = _tokenIn;
            path[1] = address(weth);
            _amountOut = IUniswapV2Router02(metadata.router).swapExactTokensForTokens(
                _amountIn,
                _amountOutMin,
                path,
                msg.sender,
                block.timestamp
            )[1];
        }

        if (metadata.version == UniswapVersion.UniswapV3) {
            // Do the swap
            IUniswapV3SwapRouter.ExactInputSingleParams memory params = IUniswapV3SwapRouter.ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: address(weth),
                fee: metadata.pool.fee(),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: _amountOutMin,
                sqrtPriceLimitX96: 0
            });
            _amountOut = IUniswapV3SwapRouter(metadata.router).exactInputSingle(params);
        }

        return _amountOut;
    }

    /// @inheritdoc IUniswapAdapter
    function swapTokensForExactWETH(
        address _tokenIn,
        uint256 _wethAmount,
        uint256 _amountInMax
    ) external returns (uint256 _amountIn) {
        /// ███ Checks
        if (!isConfigured(_tokenIn)) revert TokenNotConfigured(_tokenIn);

        /// ███ Interactions
        LiquidityData memory metadata = liquidities[_tokenIn];
        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountInMax);
        IERC20(_tokenIn).safeIncreaseAllowance(metadata.router, _amountInMax);

        if (metadata.version == UniswapVersion.UniswapV2) {
            // Do the swap
            address[] memory path = new address[](2);
            path[0] = _tokenIn;
            path[1] = address(weth);
            _amountIn = IUniswapV2Router02(metadata.router).swapTokensForExactTokens(
                _wethAmount,
                _amountInMax,
                path,
                msg.sender,
                block.timestamp
            )[1];
        }

        if (metadata.version == UniswapVersion.UniswapV3) {
            // Do the swap
            IUniswapV3SwapRouter.ExactOutputSingleParams memory params = IUniswapV3SwapRouter.ExactOutputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: address(weth),
                fee: metadata.pool.fee(),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: _wethAmount,
                amountInMaximum: _amountInMax,
                sqrtPriceLimitX96: 0
            });
            _amountIn = IUniswapV3SwapRouter(metadata.router).exactOutputSingle(params);
        }

        if (_amountInMax > _amountIn) {
            // Transfer back excess token
            IERC20(_tokenIn).safeTransfer(msg.sender, _amountInMax - _amountIn);
        }
        return _amountIn;
    }

    /// @inheritdoc IUniswapAdapter
    function swapExactWETHForTokens(
        address _tokenOut,
        uint256 _wethAmount,
        uint256 _amountOutMin
    ) external returns (uint256 _amountOut) {
        /// ███ Checks
        if (!isConfigured(_tokenOut)) revert TokenNotConfigured(_tokenOut);

        /// ███ Interactions
        LiquidityData memory metadata = liquidities[_tokenOut];
        IERC20(address(weth)).safeTransferFrom(
            msg.sender,
            address(this),
            _wethAmount
        );
        weth.safeIncreaseAllowance(metadata.router, _wethAmount);

        if (metadata.version == UniswapVersion.UniswapV2) {
            // Do the swap
            address[] memory path = new address[](2);
            path[0] = address(weth);
            path[1] = _tokenOut;
            _amountOut = IUniswapV2Router02(metadata.router).swapExactTokensForTokens(
                _wethAmount,
                _amountOutMin,
                path,
                msg.sender,
                block.timestamp
            )[1];
        }

        if (metadata.version == UniswapVersion.UniswapV3) {
            // Do the swap
            IUniswapV3SwapRouter.ExactInputSingleParams memory params = IUniswapV3SwapRouter.ExactInputSingleParams({
                tokenIn: address(weth),
                tokenOut: _tokenOut,
                fee: metadata.pool.fee(),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: _wethAmount,
                amountOutMinimum: _amountOutMin,
                sqrtPriceLimitX96: 0
            });
            _amountOut = IUniswapV3SwapRouter(metadata.router).exactInputSingle(params);
        }

        return _amountOut;
    }
}
