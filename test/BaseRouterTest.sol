// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { BaseTest } from "./BaseTest.sol";

import { IFLT } from "../src/interfaces/IFLT.sol";
import { IFLTRouter } from "../src/interfaces/IFLTRouter.sol";
import { FLTRouter } from "../src/FLTRouter.sol";

/**
 * @title BaseRouterTest
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice This tests will run for all FLTs
 */
abstract contract BaseRouterTest is BaseTest {

    /// ███ Libraries ████████████████████████████████████████████████████████

    using FixedPointMathLib for uint256;


    /// ███ Tests ████████████████████████████████████████████████████████████

    /// @notice Make sure getAmountIn revert if FLT is invalid
    function testRouterGetAmountInRevertIfFLTIsInvalid() public {
        // Setup contracts
        Data memory data = getData();
        FLTRouter router = new FLTRouter(data.factory);

        // Test
        address flt = vm.addr(1);
        address tokenIn = vm.addr(2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLTRouter.InvalidFLT.selector
            )
        );
        router.getAmountIn(flt, tokenIn, 1 ether);
    }

    /// @notice Make sure getAmountIn revert if tokenIn is invalid
    function testRouterGetAmountInRevertIfTokenInIsInvalid() public {
        // Setup contracts
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);
        FLTRouter router = new FLTRouter(data.factory);

        // Test
        address tokenIn = vm.addr(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLTRouter.InvalidTokenIn.selector
            )
        );
        router.getAmountIn(address(flt), tokenIn, 1 ether);
    }

    /// @notice Make sure getAmountIn return 0 if amountOut is zero
    function testRouterGetAmountInReturnZeroIfAmountOutZero() public {
        // Setup contracts
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);
        FLTRouter router = new FLTRouter(data.factory);

        // Test
        address tokenIn = address(flt.debt());
        uint256 amountIn = router.getAmountIn(address(flt), tokenIn, 0);
        assertEq(amountIn, 0, "invalid debt amountIn");

        tokenIn = address(flt.collateral());
        amountIn = router.getAmountIn(address(flt), tokenIn, 0);
        assertEq(amountIn, 0, "invalid collateral amountIn");
    }

    /// @notice Make sure getAmountIn return fair amount
    function testRouterGetAmountIn() public {
        // Setup contracts
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);
        FLTRouter router = new FLTRouter(data.factory);

        // Test
        uint256 amountOut = 10 ether;
        uint256 amountOutValueInETH = flt.value(amountOut);

        // Get debt token amount
        address tokenIn = address(flt.debt());
        uint256 amountIn = router.getAmountIn(
            address(flt),
            tokenIn,
            amountOut
        );
        // Get the value
        uint256 amountInValueInETH = flt.oracleAdapter().totalValue(
            address(flt.debt()),
            address(0),
            amountIn
        );
        uint256 percentage = 0.02 ether; // 2%
        uint256 tolerance = percentage.mulWadDown(amountOutValueInETH);
        assertGt(
            amountInValueInETH,
            amountOutValueInETH - tolerance,
            "debt invalid"
        );
        assertLt(
            amountInValueInETH,
            amountOutValueInETH + tolerance,
            "debt invalid"
        );

        // Get collateral token amount
        tokenIn = address(flt.collateral());
        amountIn = router.getAmountIn(
            address(flt),
            tokenIn,
            amountOut
        );
        // Get the value
        amountInValueInETH = flt.oracleAdapter().totalValue(
            address(flt.collateral()),
            address(0),
            amountIn
        );
        assertGt(
            amountInValueInETH,
            amountOutValueInETH - tolerance,
            "collateral invalid"
        );
        assertLt(
            amountInValueInETH,
            amountOutValueInETH + tolerance,
            "collateral invalid"
        );

    }
}
