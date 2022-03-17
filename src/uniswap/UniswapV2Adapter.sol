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


    /// ███ Errors █████████████████████████████████████████████████████████████

    error FlashSwapAmountCannotBeZero();
    error FlashSwapBorrowTokenPairNotFound();
    error FlashSwapRepayTokenPairNotFound();
    error FlashSwapNotAuthorized();


    /// ███ Constuctors ████████████████████████████████████████████████████████

    constructor(address _router) {
        router = _router;
        weth = IUniswapV2Router02(_router).WETH();
    }


    /// ███ Callbacks ██████████████████████████████████████████████████████████

    /// @notice Function is called by the Uniswap V2 pair's `swap` function
    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes memory _data) external {
        /// ███ Checks
        (address flasher, address borrowToken, uint256 borrowAmount, address repayToken) = abi.decode(_data, (address, address, uint256, address));

        // Check pairs
        address borrowPair = IUniswapV2Factory(IUniswapV2Router02(router).factory()).getPair(borrowToken, weth);
        address repayPair = IUniswapV2Factory(IUniswapV2Router02(router).factory()).getPair(repayToken, weth);
        if (borrowPair == address(0)) revert FlashSwapBorrowTokenPairNotFound();
        if (repayPair == address(0)) revert FlashSwapRepayTokenPairNotFound();

        // Check caller
        if (msg.sender != repayPair) revert FlashSwapNotAuthorized();

        // Check flash swap initiator
        if (_sender != address(this)) revert FlashSwapNotAuthorized();

        /// ███ Effects

        /// ███ Interactions

        // Get weth amount and gOHM amount
        uint256 wethAmount = _amount0 == 0 ? _amount1 : _amount0;

        // Step 4:
        // Swap WETH to the borrowToken
        address token0 = IUniswapV2Pair(borrowPair).token0();
        address token1 = IUniswapV2Pair(borrowPair).token1();
        uint256 amount0Out = borrowToken == token0 ? borrowAmount : 0;
        uint256 amount1Out = borrowToken == token1 ? borrowAmount : 0;
        IERC20(weth).safeTransfer(borrowPair, wethAmount);
        IUniswapV2Pair(borrowPair).swap(amount0Out, amount1Out, address(this), bytes(""));

        // Step 5:
        // Transfer borrowToken to flasher
        IERC20(borrowToken).safeTransfer(flasher, borrowAmount);

        // Step 6:
        // Calculate how much repayToken we need to repay to repayToken/WETH
        // liquidity pair for wethAmount of WETH
        address[] memory path = new address[](2);
        path[0] = repayToken;
        path[1] = weth;
        uint256 repayAmount = router.getAmountsIn(wethAmount, path)[0];

        // Step 7:
        // Call the flasher
        IFlashSwapper(flasher).flashCallback(borrowToken, borrowAmount, repayToken, repayAmount);

        // Step 8:
        // Repay the flashswap
        IERC20(repayToken).safeTransfer(repayPair, repayAmount);
    }

    /// ███ Adapters ███████████████████████████████████████████████████████████

    /**
     * @notice Trigger the flash swap
     * @dev The msg.sender should implement IFlashSwapper
     * @param _amount The flash swapped amount
     */
    function flash(address _borrowToken, uint256 _amount, address _repayToken) public {
        /// ███ Checks

        // Check amount
        if (_amount == 0) revert FlashSwapAmountCannotBeZero();

        // Check pairs
        address borrowPair = IUniswapV2Factory(IUniswapV2Router02(router).factory()).getPair(_borrowToken, weth);
        address repayPair = IUniswapV2Factory(IUniswapV2Router02(router).factory()).getPair(_repayToken, weth);
        if (borrowPair == address(0)) revert FlashSwapBorrowTokenPairNotFound();
        if (repayPair == address(0)) revert FlashSwapRepayTokenPairNotFound();

        /// ███ Effects

        /// ███ Interactions

        // Step 1:
        // Calculate how much WETH we need to borrow from `_repayToken`/WETH
        // liquidity pair to get `_amount` of `_borrowToken`.
        address[] memory path = new address[](2);
        path[0] = weth; // WETH address
        path[1] = _borrowToken; // Borrow token address (e.g. gOHM)
        uint256 wethAmount = IUniswapV2Router02(router).getAmountsIn(_amount, path)[0];

        // Step 2:
        // Borrow WETH from `_repayToken`/WETH liquidity pair (e.g. USDC/WETH)
        address token0 = IUniswapV2Pair(repayPair).token0();
        address token1 = IUniswapV2Pair(repayPair).token1();
        uint256 amount0Out = weth == token0 ? wethAmount : 0;
        uint256 amount1Out = weth == token1 ? wethAmount : 0;

        // Step 3:
        // Perform the flashswap to Uniswap V2; Step 4 in uniswapV2Call
        bytes memory data = abi.encode(msg.sender, _borrowToken, _amount, _repayToken);
        IUniswapV2Pair(repayPair).swap(amount0Out, amount1Out, address(this), data);
    }
}
