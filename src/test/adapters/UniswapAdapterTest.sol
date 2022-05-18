// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IVM } from "../IVM.sol";

import { weth, wbtc } from "chain/Tokens.sol";
import { uniswapV3WBTCETHPool, uniswapV3Router } from "chain/Tokens.sol";
import { sushiRouter, sushiWBTCETHPair } from "chain/Tokens.sol";
import { UniswapAdapter } from "../../adapters/UniswapAdapter.sol";
import { HEVM } from "../hevm/HEVM.sol";
import { IUniswapV2Pair } from "../../interfaces/IUniswapV2Pair.sol";
import { IUniswapV3Pool } from "../../interfaces/IUniswapV3Pool.sol";
import { IUniswapAdapter } from "../../interfaces/IUniswapAdapter.sol";

/**
 * @title Uniswap Adapter Test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract UniswapAdapterTest {

    /// ███ Storages █████████████████████████████████████████████████████████

    IVM vm = IVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);


    /// ███ configure ████████████████████████████████████████████████████████

    /// @notice Make sure only owner can configure token
    function testConfigureAsNonOwnerRevert() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Transfer ownership to new owner
        address newOwner = vm.addr(1);
        adapter.transferOwnership(newOwner);

        // Non-owner trying to set the token metadata; This should be reverted
        vm.expectRevert("Ownable: caller is not the owner");
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV3,
            uniswapV3WBTCETHPool,
            uniswapV3Router
        );
    }

    /// @notice Make sure owner can configure the token
    function testConfigureAsOwner() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner configure token
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV3,
            uniswapV3WBTCETHPool,
            uniswapV3Router
        );

        (
            IUniswapAdapter.UniswapVersion version,
            IUniswapV2Pair pair,
            IUniswapV3Pool pool,
            address router
        ) = adapter.liquidities(wbtc);

        // Check the version
        require(
            uint256(version) == uint256(IUniswapAdapter.UniswapVersion.UniswapV3),
            "invalid version"
        );

        // Check pair / pool
        require(address(pair) == uniswapV3WBTCETHPool, "invalid pair");
        require(address(pool) == uniswapV3WBTCETHPool, "invalid pool");

        // Check router
        require(router == uniswapV3Router, "invalid router");
    }


    /// ███ uniswapV2Call ████████████████████████████████████████████████████

    /// @notice Make sure the uniswapV2Callback revert if caller not authorized
    function testUniswapV2CallbackRevertIfCallerNotAuthorized() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // This contract is not authorized to call the callback
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapAdapter.CallerNotAuthorized.selector
            )
        );
        adapter.uniswapV2Call(address(this), 0, 0, bytes(""));
    }


    /// ███ uniswapV3SwapCallback ████████████████████████████████████████████

    /// @notice Make sure the uniswapV3SwapCallback revert if caller is not
    ///         authorized
    function testUniswapV3SwapCallbackRevertIfCallerNotAuthorized() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // This contract is not authorized to call the callback
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapAdapter.CallerNotAuthorized.selector
            )
        );
        adapter.uniswapV3SwapCallback(0, 0, bytes(""));
    }


    /// ███ isConfigured █████████████████████████████████████████████████████

    /// @notice Make sure isConfigured returns correct value
    function testIsConfigured() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata
        address token1 = vm.addr(1);
        address token2 = vm.addr(2);
        address token3 = vm.addr(3);
        address pairOrPool = vm.addr(4);
        address router = vm.addr(5);

        // Configure token1 and token2
        adapter.configure(
            token1,
            IUniswapAdapter.UniswapVersion.UniswapV3,
            pairOrPool,
            router
        );
        adapter.configure(
            token2,
            IUniswapAdapter.UniswapVersion.UniswapV2,
            pairOrPool,
            router
        );

        // Check configured value
        require(adapter.isConfigured(token1), "invalid token1");
        require(adapter.isConfigured(token2), "invalid token2");
        require(!adapter.isConfigured(token3), "invalid token3");
    }

//    enum TestType { CallerRepay, CallerNotRepay }
//
//    /// @notice Make sure flashSwapWETHForExactTokens is working on Uniswap V2
//    function testUniswapV2FlashSwapETHForExactTokens() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV2, sushiWBTCETHPair, sushiRouter);
//
//        // Execute the flashswap
//        bytes memory data = abi.encode(TestType.CallerRepay, 2022);
//        adapter.flashSwapWETHForExactTokens(wbtc, 1e8, data);
//    }
//
//    /// @notice Make sure flashSwapWETHForExactTokens is failed when token is not repay
//    function testFailUniswapV2FlashSwapETHForExactTokensRevertedIfCallerNotRepay() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV2, sushiWBTCETHPair, sushiRouter);
//
//        // Execute the flashswap without repay; this should be reverted
//        bytes memory data = abi.encode(TestType.CallerNotRepay, 2022);
//        adapter.flashSwapWETHForExactTokens(wbtc, 1e8, data);
//    }
//
//    /// @notice Make sure flashSwapWETHForExactTokens is working on Uniswap V3
//    function testUniswapV3FlashSwapETHForExactTokens() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV3, uniswapV3WBTCETHPool, uniswapV3Router);
//
//        // Execute the flashswap
//        bytes memory data = abi.encode(TestType.CallerRepay, 2022);
//        adapter.flashSwapWETHForExactTokens(wbtc, 1e8, data);
//    }
//
//    /// @notice Make sure flashSwapWETHForExactTokens is failed when token is not repay
//    function testFailUniswapV3FlashSwapETHForExactTokensRevertedIfCallerNotRepay() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV3, uniswapV3WBTCETHPool, uniswapV3Router);
//
//        // Execute the flashswap without repay; this should be reverted
//        bytes memory data = abi.encode(TestType.CallerNotRepay, 2022);
//        adapter.flashSwapWETHForExactTokens(wbtc, 1e8, data);
//    }
//
//    /// @notice Check the callback
//    function onFlashSwapWETHForExactTokens(uint256 _wethAmount, uint256 _amountOut, bytes memory _data) external {
//        assertGt(_wethAmount, 0, "check _wethAmount");
//        assertGt(_amountOut, 0, "check _amountOut");
//        assertEq(IERC20(wbtc).balanceOf(address(this)), _amountOut, "check balance");
//
//        // Check passed data
//        (TestType testType, uint256 pin) = abi.decode(_data, (TestType, uint256));
//        assertEq(pin, 2022, "check pin");
//        if (testType == TestType.CallerRepay) {
//            hevm.setWETHBalance(address(this), _wethAmount);
//            IERC20(weth).safeTransfer(msg.sender, _wethAmount);
//            return;
//        }
//        if (testType == TestType.CallerNotRepay) {
//            // Do nothing; this should be reverted
//            return;
//        }
//    }
//
//
//
//    /// @notice Make sure flashSwapWETHForExactTokens revert if the token is not configured
//    function testFailFlashSwapETHForExactTokensRevertIfTokenIsNotConfigured() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Call the flash swap
//        adapter.flashSwapWETHForExactTokens(hevm.addr(1), 1 ether, bytes(""));
//    }
//
//    /// @notice Make sure swapExactTokensForWETH revert if the token is not configured
//    function testFailSwapExactTokensForWETHRevertIfTokenIsNotConfigured() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Call the flash swap
//        adapter.swapExactTokensForWETH(hevm.addr(1), 1 ether, 1 ether);
//    }
//
//    /// @notice Make sure the its working properly on Uniswap V2
//    function testUniswapV2SwapExactTokensForWETH() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV2, sushiWBTCETHPair, sushiRouter);
//
//        // Swap the BTC
//        hevm.setWBTCBalance(address(this), 1e8);
//        IERC20(wbtc).approve(address(adapter), 1e8);
//        uint256 wethAmount = adapter.swapExactTokensForWETH(wbtc, 1e8, 0);
//        IERC20(wbtc).approve(address(adapter), 0);
//
//        // Check
//        assertEq(IERC20(wbtc).balanceOf(address(this)), 0);
//        assertEq(IERC20(weth).balanceOf(address(this)), wethAmount);
//
//    }
//
//    function testUniswapV3SwapExactTokensForWETH() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV3, uniswapV3WBTCETHPool, uniswapV3Router);
//
//        // Swap the BTC
//        hevm.setWBTCBalance(address(this), 1e8);
//        IERC20(wbtc).approve(address(adapter), 1e8);
//        uint256 wethAmount = adapter.swapExactTokensForWETH(wbtc, 1e8, 0);
//        IERC20(wbtc).approve(address(adapter), 0);
//
//        // Check
//        assertEq(IERC20(wbtc).balanceOf(address(this)), 0);
//        assertEq(IERC20(weth).balanceOf(address(this)), wethAmount);
//    }
//
//    function testFailUniswapV2SwapExactTokensForWETHAmountOutMin() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV2, sushiWBTCETHPair, sushiRouter);
//
//        // Swap the BTC
//        hevm.setWBTCBalance(address(this), 1e8);
//        IERC20(wbtc).approve(address(adapter), 1e8);
//        adapter.swapExactTokensForWETH(wbtc, 1e8, 10_000 ether); // This should be reverted
//    }
//
//    function testFailUniswapV3SwapExactTokensForWETHAmountOutMin() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV3, uniswapV3WBTCETHPool, uniswapV3Router);
//
//        // Swap the BTC
//        hevm.setWBTCBalance(address(this), 1e8);
//        IERC20(wbtc).approve(address(adapter), 1e8);
//        adapter.swapExactTokensForWETH(wbtc, 1e8, 10_000 ether); // This should be reverted
//    }
//
//    /// @notice Make sure swapTokensForExactWETH revert if the token is not configured
//    function testFailSwapTokensForExactWETHRevertIfTokenIsNotConfigured() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Call the flash swap
//        adapter.swapTokensForExactWETH(hevm.addr(1), 1 ether, 1 ether);
//    }
//
//    /// @notice Make sure the its working properly on Uniswap V2
//    function testUniswapV2SwapTokensForExactWETH() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV2, sushiWBTCETHPair, sushiRouter);
//
//        // Swap the BTC
//        hevm.setWBTCBalance(address(this), 1e8);
//        IERC20(wbtc).approve(address(adapter), 1e8);
//        uint256 wethAmount = adapter.swapTokensForExactWETH(wbtc, 1e18, 1e8);
//        IERC20(wbtc).approve(address(adapter), 0);
//
//        // Check
//        assertEq(IERC20(wbtc).balanceOf(address(this)), 0);
//        assertEq(IERC20(weth).balanceOf(address(this)), wethAmount);
//    }
//
//    function testUniswapV3SwapTokensForExactWETH() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV3, uniswapV3WBTCETHPool, uniswapV3Router);
//
//        // Swap the BTC
//        hevm.setWBTCBalance(address(this), 1e8);
//        IERC20(wbtc).approve(address(adapter), 1e8);
//        uint256 amountIn = adapter.swapTokensForExactWETH(wbtc, 1e18, 1e8);
//        IERC20(wbtc).approve(address(adapter), 0);
//
//        // Check
//        assertEq(IERC20(wbtc).balanceOf(address(this)), 1e8 - amountIn, "check wbtc balance");
//        assertEq(IERC20(weth).balanceOf(address(this)), 1e18, "check weth balance");
//    }
//
//    function testFailUniswapV2SwapTokensForExactWETHAmountInMax() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV2, sushiWBTCETHPair, sushiRouter);
//
//        // Swap the BTC
//        hevm.setWBTCBalance(address(this), 1e8);
//        IERC20(wbtc).approve(address(adapter), 1e8);
//        adapter.swapTokensForExactWETH(wbtc, 1e18, 0); // This should be reverted
//    }
//
//    function testFailUniswapV3SwapTokensForExactWETHAmountInMax() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV3, uniswapV3WBTCETHPool, uniswapV3Router);
//
//        // Swap the BTC
//        hevm.setWBTCBalance(address(this), 1e8);
//        IERC20(wbtc).approve(address(adapter), 1e8);
//        adapter.swapTokensForExactWETH(wbtc, 1e18, 0); // This should be reverted
//    }
//
//    function testFailSwapExactWETHForTokensRevertIfTokenIsNotConfigured() public {
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//        adapter.swapExactWETHForTokens(hevm.addr(1), 1 ether, 1 ether);
//    }
//
//    function testUniswapV2SwapExactWETHForTokens() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV2, sushiWBTCETHPair, sushiRouter);
//
//        // Swap the WETH
//        hevm.setWETHBalance(address(this), 1 ether);
//        IERC20(weth).approve(address(adapter), 1 ether);
//        uint256 wbtcAmount = adapter.swapExactWETHForTokens(wbtc, 1 ether, 0);
//        IERC20(weth).approve(address(adapter), 0);
//
//        // Check
//        assertEq(IERC20(wbtc).balanceOf(address(this)), wbtcAmount);
//        assertEq(IERC20(weth).balanceOf(address(this)), 0);
//    }
//
//    function testUniswapV3SwapExactWETHForTokens() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV3, uniswapV3WBTCETHPool, uniswapV3Router);
//
//        // Swap the WETH
//        hevm.setWETHBalance(address(this), 1 ether);
//        IERC20(weth).approve(address(adapter), 1 ether);
//        uint256 wbtcAmount = adapter.swapExactWETHForTokens(wbtc, 1 ether, 0);
//        IERC20(wbtc).approve(address(adapter), 0);
//
//        // Check
//        assertEq(IERC20(wbtc).balanceOf(address(this)), wbtcAmount);
//        assertEq(IERC20(weth).balanceOf(address(this)), 0);
//    }
//
//    function testFailUniswapV2SwapExactWETHForTokensAmountOutMin() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV2, sushiWBTCETHPair, sushiRouter);
//
//        // Swap the WETH
//        hevm.setWETHBalance(address(this), 1 ether);
//        IERC20(weth).approve(address(adapter), 1 ether);
//        adapter.swapExactTokensForWETH(wbtc, 1 ether, 10 * 1e8); // This should be reverted
//    }
//
//    function testFailUniswapV3SwapExactWETHForTokensAmountOutMin() public {
//        // Create new Uniswap Adapter
//        UniswapAdapter adapter = new UniswapAdapter(weth);
//
//        // Owner set metadata for wbtc
//        adapter.configure(wbtc, IUniswapAdapter.UniswapVersion.UniswapV3, uniswapV3WBTCETHPool, uniswapV3Router);
//
//        // Swap the WETH
//        hevm.setWETHBalance(address(this), 1 ether);
//        IERC20(weth).approve(address(adapter), 1 ether);
//        adapter.swapExactTokensForWETH(wbtc, 1 ether, 10 * 1e8); // This should be reverted
//    }
}
