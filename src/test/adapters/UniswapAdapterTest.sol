// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IVM } from "../IVM.sol";
import { VMUtils } from "../VMUtils.sol";

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

import { weth, wbtc } from "chain/Tokens.sol";
import { uniswapV3WBTCETHPool, uniswapV3Router } from "chain/Tokens.sol";
import { sushiRouter, sushiWBTCETHPair } from "chain/Tokens.sol";
import { UniswapAdapter } from "../../adapters/UniswapAdapter.sol";
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
    VMUtils private utils;


    /// ███ Test Setup ███████████████████████████████████████████████████████

    function setUp() public {
        // Create utils
        utils = new VMUtils(vm);
    }


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


    /// ███ flashSwapWETHForExactTokens ██████████████████████████████████████

    /// @notice Make sure it reverts if _amountOut is zero
    function testFlashSwapWETHForExactTokensRevertIfAmountOutZero() public {
        // Create adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Expect call to revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapAdapter.InvalidAmount.selector,
                0
            )
        );
        adapter.flashSwapWETHForExactTokens(
            wbtc,
            0,
            bytes("")
        );
    }

    /// @notice Make sure it reverts if _tokenOut is not supported
    function testFlashSwapWETHForExactTokensRevertIfTokenOutNotSupported() public {
        // Create adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Expect call to revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapAdapter.TokenNotConfigured.selector,
                wbtc
            )
        );
        adapter.flashSwapWETHForExactTokens(
            wbtc,
            1e8, // 1 WBTC
            bytes("")
        );
    }

    /// Utilities to test the flash swap

    enum TestType { CallerRepay, CallerNotRepay }

    function onFlashSwapWETHForExactTokens(
        uint256 _wethAmount,
        uint256 _amountOut,
        bytes memory _data
    ) external {
        // Make sure amount if correct
        require(_wethAmount > 0, "invalid _wethAmount");
        require(_amountOut > 0, "invalid _amountOut");

        // Make sure tokenOut is transfered to the flash swap caller
        uint256 balance = IERC20(wbtc).balanceOf(address(this));
        require(balance == _amountOut, "invalid balance");

        // Make sure _data is transfered properly
        (TestType testType, uint256 pin) = abi.decode(_data, (TestType, uint256));

        // Make sure data encoded properly
        require(pin == 2022, "invalid pin");

        if (testType == TestType.CallerRepay) {
            utils.setWETHBalance(address(this), _wethAmount);
            IERC20(weth).transfer(msg.sender, _wethAmount);
            return;
        }
        if (testType == TestType.CallerNotRepay) {
            // Do nothing; this should be reverted
            return;
        }
    }

    /// @notice Make sure it reverts when caller not repay
    function testFlashSwapWETHForExactTokensRevertIfCallerNotRepay() public {
        // Create adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Configure token
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV3,
            uniswapV3WBTCETHPool,
            uniswapV3Router
        );

        // Test out the repay
        bytes memory data = abi.encode(TestType.CallerNotRepay, 2022);
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapAdapter.CallerNotRepay.selector
            )
        );
        adapter.flashSwapWETHForExactTokens(wbtc, 1e8, data);
    }


    /// @notice Make sure flashSwapWETHForExactTokens is working on Uniswap V2
    function testFlashSwapWETHForExactTokensUniV2() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV2,
            sushiWBTCETHPair,
            sushiRouter
        );

        // Execute the flashswap
        bytes memory data = abi.encode(TestType.CallerRepay, 2022);
        // This will revert if flash swap failed
        // see: onFlashSwapWETHForExactTokens
        adapter.flashSwapWETHForExactTokens(wbtc, 1e8, data);
    }

    /// @notice Make sure flashSwapWETHForExactTokens is working on Uniswap V3
    function testFlashSwapWETHForExactTokensUniV3() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV3,
            uniswapV3WBTCETHPool,
            uniswapV3Router
        );

        // Execute the flashswap
        bytes memory data = abi.encode(TestType.CallerRepay, 2022);
        // This will revert if flash swap failed
        // see: onFlashSwapWETHForExactTokens
        adapter.flashSwapWETHForExactTokens(wbtc, 1e8, data);
    }


    /// ███ swapExactTokensForWETH ███████████████████████████████████████████

    /// @notice Make sure it reverts if _amountIn is zero
    function testSwapExactTokensForWETHRevertIfAmountInZero() public {
        // Create adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Expect call to revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapAdapter.InvalidAmount.selector,
                0
            )
        );
        adapter.swapExactTokensForWETH(
            wbtc,
            0,
            0
        );
    }

    /// @notice Make sure it reverts if _tokenIn is not supported
    function testSwapExactTokensForWETHRevertIfTokenInNotSupported() public {
        // Create adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Expect call to revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapAdapter.TokenNotConfigured.selector,
                wbtc
            )
        );
        adapter.swapExactTokensForWETH(
            wbtc,
            1e8, // 1 WBTC
            0
        );
    }

    /// @notice Make sure the its revert when _amountOutMin too large
    function testSwapExactTokensForWETHUniV2RevertIfAmountOutMinTooLarge() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV2,
            sushiWBTCETHPair,
            sushiRouter
        );

        // Swap the BTC
        utils.setWBTCBalance(address(this), 1e8);
        IERC20(wbtc).approve(address(adapter), 1e8);
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        adapter.swapExactTokensForWETH(wbtc, 1e8, 1000 ether);
    }

    /// @notice Make sure the its revert when _amountOutMin too large
    function testSwapExactTokensForWETHUniV3RevertIfAmountOutMinTooLarge() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV3,
            uniswapV3WBTCETHPool,
            uniswapV3Router
        );

        // Swap the BTC
        utils.setWBTCBalance(address(this), 1e8);
        IERC20(wbtc).approve(address(adapter), 1e8);
        vm.expectRevert("Too little received");
        adapter.swapExactTokensForWETH(wbtc, 1e8, 1000 ether);
    }

    /// @notice Make sure the its working properly on Uniswap V2
    function testSwapExactTokensForWETHUniV2() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV2,
            sushiWBTCETHPair,
            sushiRouter
        );

        // Swap the BTC
        utils.setWBTCBalance(address(this), 1e8);
        IERC20(wbtc).approve(address(adapter), 1e8);
        uint256 wethAmount = adapter.swapExactTokensForWETH(wbtc, 1e8, 0);
        IERC20(wbtc).approve(address(adapter), 0);

        // Check balance
        uint256 wbtcBalance = IERC20(wbtc).balanceOf(address(this));
        uint256 wethBalance = IERC20(weth).balanceOf(address(this));

        require(wbtcBalance == 0, "invalid wbtc balance");
        require(wethBalance == wethAmount, "invalid weth balance");
    }

    /// @notice Make sure the its working properly on Uniswap V3
    function testSwapExactTokensForWETHUniV3() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV3,
            uniswapV3WBTCETHPool,
            uniswapV3Router
        );

        // Swap the BTC
        utils.setWBTCBalance(address(this), 1e8);
        IERC20(wbtc).approve(address(adapter), 1e8);
        uint256 wethAmount = adapter.swapExactTokensForWETH(wbtc, 1e8, 0);
        IERC20(wbtc).approve(address(adapter), 0);

        // Check balance
        uint256 wbtcBalance = IERC20(wbtc).balanceOf(address(this));
        uint256 wethBalance = IERC20(weth).balanceOf(address(this));

        require(wbtcBalance == 0, "invalid wbtc balance");
        require(wethBalance == wethAmount, "invalid weth balance");
    }


    /// ███ swapTokensForExactWETH ███████████████████████████████████████████

    /// @notice Make sure it reverts if _wethAmount is zero
    function testSwapTokensForExactWETHRevertIfWETHAmountZero() public {
        // Create adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Expect call to revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapAdapter.InvalidAmount.selector,
                0
            )
        );
        adapter.swapTokensForExactWETH(
            wbtc,
            0,
            0
        );
    }

    /// @notice Make sure it reverts if _tokenIn is not supported
    function testSwapTokensForExactWETHRevertIfTokenInNotSupported() public {
        // Create adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Expect call to revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapAdapter.TokenNotConfigured.selector,
                wbtc
            )
        );
        adapter.swapTokensForExactWETH(
            wbtc,
            1e18, // 1 WETH
            1e8 // 1 WBTC
        );
    }

    /// @notice Make sure the its revert when _amountInMax too low
    function testSwapTokensForExactWETHUniV2RevertIfAmountInMaxTooLow() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV2,
            sushiWBTCETHPair,
            sushiRouter
        );

        // Swap the BTC
        utils.setWBTCBalance(address(this), 1e8);
        IERC20(wbtc).approve(address(adapter), 1e8);
        vm.expectRevert("UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
        adapter.swapTokensForExactWETH(wbtc, 1 ether, 0);
    }

    /// @notice Make sure the its revert when _amountInMax too low
    function testSwapTokensForExactWETHUniV3RevertIfAmountInMaxTooLow() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV3,
            uniswapV3WBTCETHPool,
            uniswapV3Router
        );

        // Swap the BTC
        utils.setWBTCBalance(address(this), 1e8);
        IERC20(wbtc).approve(address(adapter), 1e8);
        vm.expectRevert("STF");
        adapter.swapTokensForExactWETH(wbtc, 1 ether, 0);
    }

    /// @notice Make sure the its working properly on Uniswap V2
    function testSwapTokensForExactWETHUniV2() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV2,
            sushiWBTCETHPair,
            sushiRouter
        );

        // Swap the BTC
        utils.setWBTCBalance(address(this), 1e8);
        IERC20(wbtc).approve(address(adapter), 1e8);
        uint256 amountIn = adapter.swapTokensForExactWETH(wbtc, 1 ether, 1e8);
        IERC20(wbtc).approve(address(adapter), 0);

        // Check balance
        uint256 wbtcBalance = IERC20(wbtc).balanceOf(address(this));
        uint256 wethBalance = IERC20(weth).balanceOf(address(this));

        require(wbtcBalance == 1e8 - amountIn, "invalid wbtc balance");
        require(wethBalance == 1 ether, "invalid weth balance");
    }

    /// @notice Make sure the its working properly on Uniswap V3
    function testSwapTokensForExactWETHUniV3() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV3,
            uniswapV3WBTCETHPool,
            uniswapV3Router
        );

        // Swap the BTC
        utils.setWBTCBalance(address(this), 1e8);
        IERC20(wbtc).approve(address(adapter), 1e8);
        uint256 amountIn = adapter.swapTokensForExactWETH(wbtc, 1 ether, 1e8);
        IERC20(wbtc).approve(address(adapter), 0);

        // Check balance
        uint256 wbtcBalance = IERC20(wbtc).balanceOf(address(this));
        uint256 wethBalance = IERC20(weth).balanceOf(address(this));

        require(wbtcBalance == 1e8 - amountIn, "invalid wbtc balance");
        require(wethBalance == 1 ether, "invalid weth balance");
    }


    /// ███ swapExactWETHForTokens ███████████████████████████████████████████

    /// @notice Make sure it reverts if _wethAmount is zero
    function testSwapExactWETHForTokensRevertIfWETHAmountZero() public {
        // Create adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Expect call to revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapAdapter.InvalidAmount.selector,
                0
            )
        );
        adapter.swapExactWETHForTokens(
            wbtc,
            0,
            0
        );
    }

    /// @notice Make sure it reverts if _tokenOut is not supported
    function testSwapExactWETHForTokensRevertIfTokenOutNotSupported() public {
        // Create adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Expect call to revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IUniswapAdapter.TokenNotConfigured.selector,
                wbtc
            )
        );
        adapter.swapExactWETHForTokens(
            wbtc,
            1e18, // 1 WETH
            0
        );
    }

    /// @notice Make sure the its revert when _amountOutMin too large
    function testSwapExactWETHForTokensUniV2RevertIfAmountOutMinTooLarge() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV2,
            sushiWBTCETHPair,
            sushiRouter
        );

        // Swap the WETH
        utils.setWETHBalance(address(this), 1e18);
        IERC20(weth).approve(address(adapter), 1e18);
        vm.expectRevert("UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
        adapter.swapExactWETHForTokens(wbtc, 1e18, 1e8);
    }

    /// @notice Make sure the its revert when _amountOutMin too large
    function testSwapExactWETHForTokensUniV3RevertIfAmountOutMinTooLarge() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV3,
            uniswapV3WBTCETHPool,
            uniswapV3Router
        );

        // Swap the WETH
        utils.setWETHBalance(address(this), 1e18);
        IERC20(weth).approve(address(adapter), 1e18);
        vm.expectRevert("Too little received");
        adapter.swapExactWETHForTokens(wbtc, 1e18, 1e8);
    }

    /// @notice Make sure the its working properly on Uniswap V2
    function testSwapExactWETHForTokensUniV2() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV2,
            sushiWBTCETHPair,
            sushiRouter
        );

        // Swap the WETH
        utils.setWETHBalance(address(this), 1e18);
        IERC20(weth).approve(address(adapter), 1e18);
        uint256 amountOut = adapter.swapExactWETHForTokens(wbtc, 1e18, 0);
        IERC20(wbtc).approve(address(adapter), 0);

        // Check balance
        uint256 wbtcBalance = IERC20(wbtc).balanceOf(address(this));
        uint256 wethBalance = IERC20(weth).balanceOf(address(this));

        require(wbtcBalance == amountOut, "invalid wbtc balance");
        require(wethBalance == 0, "invalid weth balance");
    }

    /// @notice Make sure the its working properly on Uniswap V3
    function testSwapExactWETHForTokensUniV3() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata for wbtc
        adapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV3,
            uniswapV3WBTCETHPool,
            uniswapV3Router
        );

        // Swap the WETH
        utils.setWETHBalance(address(this), 1e18);
        IERC20(weth).approve(address(adapter), 1e18);
        uint256 amountOut = adapter.swapExactWETHForTokens(wbtc, 1e18, 0);
        IERC20(weth).approve(address(adapter), 0);

        // Check balance
        uint256 wbtcBalance = IERC20(wbtc).balanceOf(address(this));
        uint256 wethBalance = IERC20(weth).balanceOf(address(this));

        require(wbtcBalance == amountOut, "invalid wbtc balance");
        require(wethBalance == 0, "invalid weth balance");
    }
}
