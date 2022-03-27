// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { weth, wbtc } from "chain/Tokens.sol";
import { uniswapV3WBTCETHPool, uniswapV3Router } from "chain/Tokens.sol";
import { sushiRouter, sushiWBTCETHPair } from "chain/Tokens.sol";
import { UniswapAdapter } from "../../uniswap/UniswapAdapter.sol";
import { HEVM } from "../hevm/HEVM.sol";
import { IUniswapV2Pair } from "../../interfaces/IUniswapV2Pair.sol";
import { IUniswapV3Pool } from "../../interfaces/IUniswapV3Pool.sol";

/**
 * @title Uniswap Adapter Test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract UniswapAdapterTest is DSTest {

    using SafeERC20 for IERC20;
    HEVM private hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    /// @notice Make sure only owner can set token metadata
    function testFailNonOwnerCannotSetTokenMetadata() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Transfer ownership to new owner
        address newOwner = hevm.addr(1);
        adapter.transferOwnership(newOwner);

        // Non-owner trying to set the token metadata; This should be reverted
        adapter.setMetadata(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);
    }

    /// @notice Make sure owner can set token metadata
    function testOwnerCanSetMetadata() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata
        adapter.setMetadata(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);

        // Check the value
        (uint8 version, IUniswapV2Pair pair, IUniswapV3Pool pool, address router) = adapter.tokens(wbtc);
        assertEq(version, 3);
        // Pair and pool is set to the same address
        assertEq(address(pair), uniswapV3WBTCETHPool);
        assertEq(address(pool), uniswapV3WBTCETHPool);
        // Router
        assertEq(router, uniswapV3Router);
    }

    /// @notice Make sure isConfigured returns correct value
    function testIsConfigured() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata
        address token1 = hevm.addr(1);
        address token2 = hevm.addr(2);
        address token3 = hevm.addr(3);
        address pairOrPool = hevm.addr(4);
        address router = hevm.addr(5);

        adapter.setMetadata(token1, 3, pairOrPool, router);
        adapter.setMetadata(token2, 2, pairOrPool, router);

        // Check configured value
        assertTrue(adapter.isConfigured(token1), "token1");
        assertTrue(adapter.isConfigured(token2), "token2");
        assertTrue(!adapter.isConfigured(token3), "token3");
    }

    enum TestType { CallerRepay, CallerNotRepay }

    /// @notice Make sure flashSwapETHForExactTokens is working on Uniswap V2
    function testUniswapV2FlashSwapETHForExactTokens() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.setMetadata(wbtc, 2, sushiWBTCETHPair, sushiRouter);

        // Execute the flashswap
        bytes memory data = abi.encode(TestType.CallerRepay, 2022);
        adapter.flashSwapETHForExactTokens(wbtc, 1e8, data);
    }

    /// @notice Make sure flashSwapETHForExactTokens is failed when token is not repay
    function testFailUniswapV2FlashSwapETHForExactTokensRevertedIfCallerNotRepay() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.setMetadata(wbtc, 2, sushiWBTCETHPair, sushiRouter);

        // Execute the flashswap without repay; this should be reverted
        bytes memory data = abi.encode(TestType.CallerNotRepay, 2022);
        adapter.flashSwapETHForExactTokens(wbtc, 1e8, data);
    }

    /// @notice Make sure flashSwapETHForExactTokens is working on Uniswap V3
    function testUniswapV3FlashSwapETHForExactTokens() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.setMetadata(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);

        // Execute the flashswap
        bytes memory data = abi.encode(TestType.CallerRepay, 2022);
        adapter.flashSwapETHForExactTokens(wbtc, 1e8, data);
    }

    /// @notice Make sure flashSwapETHForExactTokens is failed when token is not repay
    function testFailUniswapV3FlashSwapETHForExactTokensRevertedIfCallerNotRepay() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.setMetadata(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);

        // Execute the flashswap without repay; this should be reverted
        bytes memory data = abi.encode(TestType.CallerNotRepay, 2022);
        adapter.flashSwapETHForExactTokens(wbtc, 1e8, data);
    }

    /// @notice Check the callback
    function onFlashSwapETHForExactTokens(uint256 _wethAmount, uint256 _amountOut, bytes memory _data) external {
        assertGt(_wethAmount, 0, "check _wethAmount");
        assertGt(_amountOut, 0, "check _amountOut");
        assertEq(IERC20(wbtc).balanceOf(address(this)), _amountOut, "check balance");

        // Check passed data
        (TestType testType, uint256 pin) = abi.decode(_data, (TestType, uint256));
        assertEq(pin, 2022, "check pin");
        if (testType == TestType.CallerRepay) {
            hevm.setWETHBalance(address(this), _wethAmount);
            IERC20(weth).safeTransfer(msg.sender, _wethAmount);
            return;
        }
        if (testType == TestType.CallerNotRepay) {
            // Do nothing; this should be reverted
            return;
        }
    }

    /// @notice Make sure the uniswapV2Callback cannot be called by random dude
    function testFailUniswapV2CallbackCannotBeCalledByRandomDude() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Random dude try to execute the UniswapV2Callback; should be failed
        adapter.uniswapV2Call(address(this), 0, 0, bytes(""));
    }

    /// @notice Make sure the uniswapV3SwapCallback cannot be called by random dude
    function testFailUniswapV3SwapCallbackCannotBeCalledByRandomDude() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Random dude try to execute the UniswapV2Callback; should be failed
        adapter.uniswapV3SwapCallback(0, 0, bytes(""));
    }

    /// @notice Make sure flashSwapETHForExactTokens revert if the token is not configured
    function testFailFlashSwapETHForExactTokensRevertIfTokenIsNotConfigured() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Call the flash swap
        adapter.flashSwapETHForExactTokens(hevm.addr(1), 1 ether, bytes(""));
    }

    /// @notice Make sure swapExactTokensForWETH revert if the token is not configured
    function testFailSwapExactTokensForWETHRevertIfTokenIsNotConfigured() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Call the flash swap
        adapter.swapExactTokensForWETH(hevm.addr(1), 1 ether, 1 ether);
    }

    /// @notice Make sure the its working properly on Uniswap V2
    function testUniswapV2SwapExactTokensForWETH() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.setMetadata(wbtc, 2, sushiWBTCETHPair, sushiRouter);

        // Swap the BTC
        hevm.setWBTCBalance(address(this), 1e8);
        IERC20(wbtc).approve(address(adapter), 1e8);
        uint256 wethAmount = adapter.swapExactTokensForWETH(wbtc, 1e8, 0);
        IERC20(wbtc).approve(address(adapter), 0);

        // Check
        assertEq(IERC20(wbtc).balanceOf(address(this)), 0);
        assertEq(IERC20(weth).balanceOf(address(this)), wethAmount);

    }

    function testUniswapV3SwapExactTokensForWETH() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.setMetadata(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);

        // Swap the BTC
        hevm.setWBTCBalance(address(this), 1e8);
        IERC20(wbtc).approve(address(adapter), 1e8);
        uint256 wethAmount = adapter.swapExactTokensForWETH(wbtc, 1e8, 0);
        IERC20(wbtc).approve(address(adapter), 0);

        // Check
        assertEq(IERC20(wbtc).balanceOf(address(this)), 0);
        assertEq(IERC20(weth).balanceOf(address(this)), wethAmount);
    }

    function testFailUniswapV2SwapExactTokensForWETHAmountOutMin() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.setMetadata(wbtc, 2, sushiWBTCETHPair, sushiRouter);

        // Swap the BTC
        hevm.setWBTCBalance(address(this), 1e8);
        IERC20(wbtc).approve(address(adapter), 1e8);
        adapter.swapExactTokensForWETH(wbtc, 1e8, 10_000 ether); // This should be reverted
    }

    function testFailUniswapV3SwapExactTokensForWETHAmountOutMin() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.setMetadata(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);

        // Swap the BTC
        hevm.setWBTCBalance(address(this), 1e8);
        IERC20(wbtc).approve(address(adapter), 1e8);
        adapter.swapExactTokensForWETH(wbtc, 1e8, 10_000 ether); // This should be reverted
    }
}