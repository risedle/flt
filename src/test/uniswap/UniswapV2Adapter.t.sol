// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { UniswapV2Adapter } from "../../uniswap/UniswapV2Adapter.sol";
import { Flasher } from "./Flasher.sol";
import { gohm, usdc, sushiRouter, weth } from "../Arbitrum.sol";
import { HEVM } from "../HEVM.sol";
import { IUniswapV2Router02 } from "../../interfaces/IUniswapV2Router02.sol";

/**
 * @title Uniswap V2 Adapter Test
 * @author bayu (github.com/pyk)
 * @notice Unit testing for UniswapV2Adapter implementation
 */
contract UniswapV2AdapterTest is DSTest {
    HEVM private hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    /// @notice Flasher cannot flashSwapExactTokensForTokensViaETH with zero amount
    function testFailFlasherCannotFlashSwapExactTokensForTokensViaETHWithZeroAmountBorrowToken() public {
        // Create new adapter
        UniswapV2Adapter adapter = new UniswapV2Adapter(sushiRouter);

        // Create new Flasher
        Flasher flasher = new Flasher(address(adapter));

        // Trigger the flash swap; this should be failed
        flasher.flashSwapExactTokensForTokensViaETH(0, 0, [usdc, gohm], bytes(""));
    }

    /// @notice Flasher cannot flashSwapExactTokensForTokensViaETH with invalid tokenIn
    function testFailFlasherCannotFlashSwapExactTokensForTokensViaETHWithInvalidTokenIn() public {
        // Create new adapter
        UniswapV2Adapter adapter = new UniswapV2Adapter(sushiRouter);

        // Create new Flasher
        Flasher flasher = new Flasher(address(adapter));

        // Trigger the flash swap; this should be failed
        address randomToken = hevm.addr(1);
        flasher.flashSwapExactTokensForTokensViaETH(1 ether, 0, [randomToken, gohm], bytes(""));
    }

    /// @notice Flasher cannot flashSwapExactTokensForTokensViaETH with invalid tokenOut
    function testFailFlasherCannotFlashSwapExactTokensForTokensViaETHWithInvalidTokenOut() public {
        // Create new adapter
        UniswapV2Adapter adapter = new UniswapV2Adapter(sushiRouter);

        // Create new Flasher
        Flasher flasher = new Flasher(address(adapter));

        // Trigger the flash swap; this should be failed
        address randomToken = hevm.addr(1);
        flasher.flashSwapExactTokensForTokensViaETH(1 ether, 0, [usdc, randomToken], bytes(""));
    }

    /// @notice When flasher flashSwapExactTokensForTokensViaETH, make sure it receive the tokenOut
    function testFlasherCanFlashSwapExactTokensForTokensViaETHAndReceiveTokenOut() public {
        // Create new adapter
        UniswapV2Adapter adapter = new UniswapV2Adapter(sushiRouter);

        // Create new Flasher
        Flasher flasher = new Flasher(address(adapter));

        // Top up the flasher to repay the borrow
        hevm.setUSDCBalance(address(flasher), 10_000 * 1e6); // 10K USDC

        // Trigger the flash swap; borrow gOHM pay with USDC
        uint256 amountIn = 5_000 * 1e6; // 5K USDC
        flasher.flashSwapExactTokensForTokensViaETH(amountIn, 0, [usdc, gohm], bytes(""));

        // Get the amount out
        address[] memory tokenInToTokenOut = new address[](3);
        tokenInToTokenOut[0] = usdc;
        tokenInToTokenOut[1] = weth;
        tokenInToTokenOut[2] = gohm;
        uint256 amountOut = IUniswapV2Router02(sushiRouter).getAmountsOut(amountIn, tokenInToTokenOut)[2];

        // Check
        uint256 balance = IERC20(gohm).balanceOf(address(flasher));
        // Tolerance +-2%
        uint256 minBalance = amountOut - ((0.02 ether * balance) / 1 ether);
        uint256 maxBalance = amountOut + ((0.02 ether * balance) / 1 ether);
        assertGt(balance, minBalance);
        assertLt(balance, maxBalance);
    }

    /// @notice Make sure the uniswapV2Callback cannot be called by random dude
    function testFailUniswapV2CallCannotBeCalledByRandomDude() public {
        // Create new adapter
        UniswapV2Adapter adapter = new UniswapV2Adapter(sushiRouter);

        // Random dude try to execute the UniswapV2Callback; should be failed
        adapter.uniswapV2Call(address(this), 0, 0, bytes(""));
    }
}
