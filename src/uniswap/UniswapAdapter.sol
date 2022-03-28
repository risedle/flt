// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUniswapV2Router02 } from "../interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "../interfaces/IUniswapV2Pair.sol";
import { IUniswapV3Pool } from "../interfaces/IUniswapV3Pool.sol";
import { IUniswapV3SwapRouter } from "../interfaces/IUniswapV3SwapRouter.sol";
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

    /// @notice FlashSwapWETHForExactTokens parameters
    struct FlashSwapWETHForExactTokensParams {
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
    enum FlashSwapType {
        FlashSwapWETHForExactTokens,
        PreviewSwapWETHForExactTokens,
        PreviewSwapTokensForExactWETH,
        PreviewSwapExactTokensForWETH,
        PreviewSwapExactWETHForTokens
    }

    /// @notice Whitelisted pair/pool that can call the callback
    mapping(address => bool) private isValidCallbackCaller;


    /// ███ Events █████████████████████████████████████████████████████████████

    /// @notice Event emitted when metadata us updated
    event TokenMetadataUpdated(address token, uint8 version, address pairOrPool);

    /// @notice Event emitted when flash swap succeeded
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

    /// @notice Error is raised if preview is failed
    error PreviewFailed();


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

    /// @notice Executed when flashSwapWETHForExactTokens is triggered
    function onFlashSwapWETHForExactTokens(FlashSwapWETHForExactTokensParams memory _params, bytes memory _data) internal {
        // Transfer the tokenOut to caller
        _params.tokenOut.safeTransfer(address(_params.caller), _params.amountOut);

        // Execute the callback
        uint256 prevBalance = weth.balanceOf(address(this));
        _params.caller.onFlashSwapWETHForExactTokens(_params.wethAmount, _params.amountOut, _data);
        uint256 balance = weth.balanceOf(address(this));

        // Check the balance
        if (balance < prevBalance + _params.wethAmount) revert CallerNotRepay();

        // Transfer the WETH to the Uniswap V2 pair or pool
        if (_params.metadata.version == 2) {
            weth.safeTransfer(address(_params.metadata.pair), _params.wethAmount);
        } else {
            weth.safeTransfer(address(_params.metadata.pool), _params.wethAmount);
        }

        emit FlashSwapped(_params);
    }


    /// ███ Callbacks ██████████████████████████████████████████████████████████

    /// @notice Function is called by the Uniswap V2 pair's when swap function is executed
    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes memory _data) external {
        /// ███ Checks

        // Check caller
        if (!isValidCallbackCaller[msg.sender]) revert CallerNotAuthorized();
        if (_sender != address(this)) revert CallerNotAuthorized();

        /// ███ Interactions

        // Get the data
        (FlashSwapType flashSwapType, bytes memory data) = abi.decode(_data, (FlashSwapType, bytes));

        // Continue execute the function based on the flash swap type
        if (flashSwapType == FlashSwapType.FlashSwapWETHForExactTokens) {
            (FlashSwapWETHForExactTokensParams memory params, bytes memory callData) = abi.decode(data, (FlashSwapWETHForExactTokensParams,bytes));
            // Check the amount out
            uint256 amountOut = _amount0 == 0 ? _amount1 : _amount0;
            if (params.amountOut != amountOut) revert FlashSwapReceivedAmountInvalid(params.amountOut, amountOut);

            // Calculate the WETH amount
            address[] memory path = new address[](2);
            path[0] = address(weth);
            path[1] = address(params.tokenOut);
            params.wethAmount = IUniswapV2Router02(params.metadata.router).getAmountsIn(params.amountOut, path)[0];

            onFlashSwapWETHForExactTokens(params, callData);
            return;
        }
    }

    /**
     * @notice Function is called by the Uniswap V3 pool when the swap function is executed
     * @param _amount0Delta The amount of token0 that was sent (negative) or must
     *                      be received (positive) by the pool by the end of the swap.
     *                      If positive, the callback must send that amount of token0 to the pool.
     * @param _amount1Delta The amount of token1 that was sent (negative) or must
     *                      be received (positive) by the pool by the end of the swap.
     *                      If positive, the callback must send that amount of token1 to the pool.
     * @param _data Callback data
     */
    function uniswapV3SwapCallback(int256 _amount0Delta, int256 _amount1Delta, bytes memory _data) external {
        /// ███ Checks

        // Check caller
        if (!isValidCallbackCaller[msg.sender]) revert CallerNotAuthorized();

        /// ███ Interactions

        // Get the data
        (FlashSwapType flashSwapType, bytes memory data) = abi.decode(_data, (FlashSwapType, bytes));

        // Continue execute the function based on the flash swap type
        if (flashSwapType == FlashSwapType.FlashSwapWETHForExactTokens) {
            (FlashSwapWETHForExactTokensParams memory params, bytes memory callData) = abi.decode(data, (FlashSwapWETHForExactTokensParams,bytes));

            // if amount negative then it must be the amountOut, otherwise it's weth amount
            uint256 amountOut = _amount0Delta < 0 ?  uint256(-1 * _amount0Delta) : uint256(-1 * _amount1Delta);
            params.wethAmount = _amount0Delta > 0 ? uint256(_amount0Delta) : uint256(_amount1Delta);

            // Check the amount out
            if (params.amountOut != amountOut) revert FlashSwapReceivedAmountInvalid(params.amountOut, amountOut);

            onFlashSwapWETHForExactTokens(params, callData);
            return;
        }

        if (flashSwapType == FlashSwapType.PreviewSwapWETHForExactTokens || flashSwapType == FlashSwapType.PreviewSwapTokensForExactWETH) {
            (uint8 tokenNumber) = abi.decode(data, (uint8));
            if (tokenNumber == 0) {
                revert(string(abi.encode(uint256(_amount0Delta))));
            } else {
                revert(string(abi.encode(uint256(_amount1Delta))));
            }
        }

        // WETH/tokenOut amount is negative, coz it was sent by the pool
        if (flashSwapType == FlashSwapType.PreviewSwapExactTokensForWETH || flashSwapType == FlashSwapType.PreviewSwapExactWETHForTokens) {
            (uint8 tokenNumber) = abi.decode(data, (uint8));
            if (tokenNumber == 0) {
                revert(string(abi.encode(uint256(-1 * _amount0Delta))));
            } else {
                revert(string(abi.encode(uint256(-1 * _amount1Delta))));
            }
        }
    }


    /// ███ Read-only functions ████████████████████████████████████████████████

    /**
     * @notice Returns true if token is configured
     * @param _token The token address
     */
    function isConfigured(address _token) external view returns (bool) {
        if (tokens[_token].version == 2 || tokens[_token].version == 3) return true;
        return false;
    }

    /// ███ Adapters ███████████████████████████████████████████████████████████

    /**
     * @notice Borrow exact amount of tokenOut and repay it with WETH.
     *         The Uniswap Adapter will call msg.sender#onFlashSwapWETHForExactTokens.
     * @param _tokenOut The address of ERC20 that swapped
     * @param _amountOut The exact amount of tokenOut that will be received by the caller
     */
    function flashSwapWETHForExactTokens(address _tokenOut, uint256 _amountOut, bytes memory _data) external {
        /// ███ Checks
        if (_amountOut == 0) revert InvalidAmount(0);

        // Check the metadata
        TokenMetadata memory metadata = tokens[_tokenOut];
        if (metadata.version == 0) revert TokenNotConfigured(_tokenOut);

        /// ███ Interactions

        // Initialize the params
        FlashSwapWETHForExactTokensParams memory params = FlashSwapWETHForExactTokensParams({
            tokenOut: IERC20(_tokenOut),
            amountOut: _amountOut,
            caller: IUniswapAdapterCaller(msg.sender),
            metadata: metadata,
            wethAmount: 0 // Initialize as zero; It will be updated in the callback
        });
        bytes memory data = abi.encode(FlashSwapType.FlashSwapWETHForExactTokens, abi.encode(params, _data));

        // Flash swap Uniswap V2; The pair address will call uniswapV2Callback function
        if (metadata.version == 2) {
            // Get amountOut for token and weth
            uint256 amount0Out = _tokenOut == metadata.pair.token0() ? _amountOut : 0;
            uint256 amount1Out = _tokenOut == metadata.pair.token1() ? _amountOut : 0;

            // Do the flash swap
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
            metadata.pool.swap(address(this), zeroForOne, amountSpecified, sqrtPriceLimitX96, data);
            return;
        }
    }

    /**
     * @notice Swaps an exact amount of input tokens for as many WETH tokens as possible.
     * @param _tokenIn tokenIn address
     * @param _amountIn The amount of tokenIn
     * @param _amountOutMin The minimum amount of WETH to be received
     * @return _amountOut The WETH amount received
     */
    function swapExactTokensForWETH(address _tokenIn, uint256 _amountIn, uint256 _amountOutMin) external returns (uint256 _amountOut) {
        /// ███ Checks

        // Check the metadata
        TokenMetadata memory metadata = tokens[_tokenIn];
        if (metadata.version == 0) revert TokenNotConfigured(_tokenIn);

        /// ███ Interactions
        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);

        if (metadata.version == 2) {
            // Do the swap
            address[] memory path = new address[](2);
            path[0] = _tokenIn;
            path[1] = address(weth);
            IERC20(_tokenIn).safeApprove(metadata.router, _amountIn);
            _amountOut = IUniswapV2Router02(metadata.router).swapExactTokensForTokens(_amountIn, _amountOutMin, path, msg.sender, block.timestamp)[1];
            IERC20(_tokenIn).safeApprove(metadata.router, 0);
            return _amountOut;
        }

        if (metadata.version == 3) {
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

            IERC20(_tokenIn).safeApprove(metadata.router, _amountIn);
            _amountOut = IUniswapV3SwapRouter(metadata.router).exactInputSingle(params);
            IERC20(_tokenIn).safeApprove(metadata.router, 0);
            return _amountOut;
        }
    }

    /**
     * @notice Get the amount of WETH to get exact amount of specified token.
     * @dev The transaction will reverted if _tokenOut is not configured
     * @param _tokenOut The output token
     * @param _amountOut The amount of output token
     * @return _wethAmount The amount of WETH
     */
    function previewSwapWETHForExactTokens(address _tokenOut, uint256 _amountOut) external returns (uint256 _wethAmount) {
        /// ███ Checks

        // Early returns
        if (_amountOut == 0) return 0;

        // Check the metadata
        TokenMetadata memory metadata = tokens[_tokenOut];
        if (metadata.version == 0) revert TokenNotConfigured(_tokenOut);

        /// ███ Interactions

        if (metadata.version == 2) {
            address[] memory path = new address[](2);
            path[0] = address(weth);
            path[1] = _tokenOut;
            _wethAmount = IUniswapV2Router02(metadata.router).getAmountsIn(_amountOut, path)[0];
            return _wethAmount;
        }

        if (metadata.version == 3) {
            // Get the ETH token number
            uint8 ethTokenNumber = _tokenOut == metadata.pool.token0() ? 1 : 0;

            // zeroForOne (true: token0 -> token1) (false: token1 -> token0)
            bool zeroForOne = _tokenOut == metadata.pool.token1() ? true : false;

            // amountSpecified (Exact input: positive) (Exact output: negative)
            int256 amountSpecified = -1 * int256(_amountOut);
            uint160 sqrtPriceLimitX96 = (zeroForOne ? 4295128740 : 1461446703485210103287273052203988822378723970341);

            // Perform swap
            bytes memory data = abi.encode(FlashSwapType.PreviewSwapWETHForExactTokens, abi.encode(ethTokenNumber));
            try metadata.pool.swap(address(this), zeroForOne, amountSpecified, sqrtPriceLimitX96, data) {
                revert PreviewFailed();
            } catch Error(string memory revertData) {
                _wethAmount = abi.decode(bytes(revertData), (uint256));
            }
            return _wethAmount;
        }
    }

    /**
     * @notice Get the amount of tokenIn to get exact amount of WETH.
     * @dev The transaction will reverted if _tokenIn is not configured
     * @param _tokenIn The output token
     * @param _wethAmount The amount of WETH
     * @return _amountIn The amount of _tokenIn
     */
    function previewSwapTokensForExactWETH(address _tokenIn, uint256 _wethAmount) external returns (uint256 _amountIn) {
        /// ███ Checks

        // Early returns
        if (_wethAmount == 0) return 0;

        // Check the metadata
        TokenMetadata memory metadata = tokens[_tokenIn];
        if (metadata.version == 0) revert TokenNotConfigured(_tokenIn);

        /// ███ Interactions

        if (metadata.version == 2) {
            address[] memory path = new address[](2);
            path[0] = _tokenIn;
            path[1] = address(weth);
            _amountIn = IUniswapV2Router02(metadata.router).getAmountsIn(_wethAmount, path)[0];
            return _amountIn;
        }

        if (metadata.version == 3) {
            // Get the tokenIn token number
            uint8 tokenInNumber = _tokenIn == metadata.pool.token0() ? 0 : 1;

            // zeroForOne (true: token0 -> token1) (false: token1 -> token0)
            bool zeroForOne = _tokenIn == metadata.pool.token0() ? true : false;

            // amountSpecified (Exact input: positive) (Exact output: negative)
            int256 amountSpecified = -1 * int256(_wethAmount);
            uint160 sqrtPriceLimitX96 = (zeroForOne ? 4295128740 : 1461446703485210103287273052203988822378723970341);

            // Perform swap
            bytes memory data = abi.encode(FlashSwapType.PreviewSwapTokensForExactWETH, abi.encode(tokenInNumber));
            try metadata.pool.swap(address(this), zeroForOne, amountSpecified, sqrtPriceLimitX96, data) {
                revert PreviewFailed();
            } catch Error(string memory revertData) {
                _amountIn = abi.decode(bytes(revertData), (uint256));
            }
            return _amountIn;
        }
    }

    /**
     * @notice Get the amount of WETH given exact amount of tokenIn
     * @dev The transaction will reverted if tokenIn is not configured
     * @param _tokenIn The output token
     * @param _amountIn The amount of tokenIn
     * @return _wethAmount The amount of WETH
     */
    function previewSwapExactTokensForWETH(address _tokenIn, uint256 _amountIn) external returns (uint256 _wethAmount) {
        /// ███ Checks

        // Early returns
        if (_amountIn == 0) return 0;

        // Check the metadata
        TokenMetadata memory metadata = tokens[_tokenIn];
        if (metadata.version == 0) revert TokenNotConfigured(_tokenIn);

        /// ███ Interactions

        if (metadata.version == 2) {
            address[] memory path = new address[](2);
            path[0] = _tokenIn;
            path[1] = address(weth);
            _wethAmount = IUniswapV2Router02(metadata.router).getAmountsOut(_amountIn, path)[1];
            return _wethAmount;
        }

        if (metadata.version == 3) {
            // Get the WETH token number
            uint8 ethTokenNumber = _tokenIn == metadata.pool.token0() ? 1 : 0;

            // zeroForOne (true: token0 -> token1) (false: token1 -> token0)
            bool zeroForOne = _tokenIn == metadata.pool.token0() ? true : false;

            // amountSpecified (Exact input: positive) (Exact output: negative)
            int256 amountSpecified = int256(_amountIn);
            uint160 sqrtPriceLimitX96 = (zeroForOne ? 4295128740 : 1461446703485210103287273052203988822378723970341);

            // Perform swap
            bytes memory data = abi.encode(FlashSwapType.PreviewSwapExactTokensForWETH, abi.encode(ethTokenNumber));
            try metadata.pool.swap(address(this), zeroForOne, amountSpecified, sqrtPriceLimitX96, data) {
                revert PreviewFailed();
            } catch Error(string memory revertData) {
                _wethAmount = abi.decode(bytes(revertData), (uint256));
            }
            return _wethAmount;
        }
    }

    /**
     * @notice Get the amount of tokenOut given exact amount of WETH
     * @dev The transaction will revert if tokenOut is not configured
     * @param _tokenOut The output token
     * @param _wethAmount The amount of WETH
     * @return _amountOut The amount of tokenOut
     */
    function previewSwapExactWETHForTokens(address _tokenOut, uint256 _wethAmount) external returns (uint256 _amountOut) {
        /// ███ Checks

        // Early returns
        if (_wethAmount == 0) return 0;

        // Check the metadata
        TokenMetadata memory metadata = tokens[_tokenOut];
        if (metadata.version == 0) revert TokenNotConfigured(_tokenOut);

        /// ███ Interactions

        if (metadata.version == 2) {
            address[] memory path = new address[](2);
            path[0] = address(weth);
            path[1] = _tokenOut;
            _amountOut = IUniswapV2Router02(metadata.router).getAmountsOut(_wethAmount, path)[1];
            return _amountOut;
        }

        if (metadata.version == 3) {
            // Get the tokenOut token number
            uint8 tokenNumber = _tokenOut == metadata.pool.token0() ? 0 : 1;

            // zeroForOne (true: token0 -> token1) (false: token1 -> token0)
            bool zeroForOne = _tokenOut == metadata.pool.token1() ? true : false;

            // amountSpecified (Exact input: positive) (Exact output: negative)
            int256 amountSpecified = int256(_wethAmount);
            uint160 sqrtPriceLimitX96 = (zeroForOne ? 4295128740 : 1461446703485210103287273052203988822378723970341);

            // Perform swap
            bytes memory data = abi.encode(FlashSwapType.PreviewSwapExactWETHForTokens, abi.encode(tokenNumber));
            try metadata.pool.swap(address(this), zeroForOne, amountSpecified, sqrtPriceLimitX96, data) {
                revert PreviewFailed();
            } catch Error(string memory revertData) {
                _amountOut = abi.decode(bytes(revertData), (uint256));
            }
            return _amountOut;
        }
    }
}