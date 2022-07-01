// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { IFLT } from "../src/interfaces/IFLT.sol";

import { BaseTest } from "./BaseTest.sol";

abstract contract BaseRebalanceTest is BaseTest {

    using FixedPointMathLib for uint256;

    /// @notice Make sure leverage up revert if leverage ratio in range
    function testPushCollateralRevertIfLeverageRatioInRange() public {
        // Deploy and initialize 2x leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.Balance.selector
            )
        );
        flt.pushc();
    }

    /// @notice Make sure leverage down revert if leverage ratio in range
    function testPushDebtRevertIfLeverageRatioInRange() public {
        // Deploy and initialize 2x leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.Balance.selector
            )
        );
        flt.pushd();
    }

    /// @notice Make sure leveraging up revert if no collateral send
    function testPushCollateralRevertIfAmountInIsZero() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 1.5 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountInTooLow.selector
            )
        );
        flt.pushc();
    }

    /// @notice Make sure leveraging down revert if no debt send
    function testPushDebtRevertIfAmountInIsZero() public {
        // Deploy and initialize 2.6 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2.6 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountInTooLow.selector
            )
        );
        flt.pushd();
    }

    /// @notice Make sure leveraging up revert if amount in less than min
    function testPushCollateralRevertIfAmountInLessThanMinAmountIn() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 1.5 ether);

        // Send some collateral to contract
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            address(this),
            0.01 ether
        );
        ERC20(address(flt.collateral())).transfer(address(flt), 0.01 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountInTooLow.selector
            )
        );
        flt.pushc();
    }

    /// @notice Make sure leveraging down revert if amount in less than min
    function testPushDebtRevertIfAmountInLessThanMinAmountIn() public {
        // Deploy and initialize 2.6 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2.6 ether);

        // Send some collateral to contract
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            0.01 ether
        );
        ERC20(address(flt.debt())).transfer(address(flt), 0.01 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountInTooLow.selector
            )
        );
        flt.pushd();
    }

    /// @notice Make sure leveraging up run as expected
    function testPushCollateral() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 1.5 ether);
        uint256 lr = flt.leverageRatio();
        uint256 tc = flt.totalCollateral();
        uint256 td = flt.totalDebt();
        uint256 p = flt.price();
        uint256 ts = ERC20(address(flt)).totalSupply();

        // Send some collateral to contract
        (uint256 amountIn, uint256 amountOut) = getLeveragingUpInOut(flt);
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            address(this),
            amountIn
        );

        // Push collateral to leverage up;
        ERC20(address(flt.collateral())).transfer(address(flt), amountIn);
        flt.pushc();

        // Make sure leverage ratio is up
        uint256 clr = flt.leverageRatio();
        assertGt(clr, lr + flt.step() - 0.05 ether, "too low");
        assertLt(clr, lr + flt.step() + 0.05 ether, "too high");

        // Make sure total collateral and debt is increased
        uint256 ctc = flt.totalCollateral();
        uint256 ctd = flt.totalDebt();
        assertEq(ctc, tc + amountIn, "invalid tc");
        assertEq(ctd, td + amountOut, "invalid td");

        // Make sure price doesn't change
        uint256 cp = flt.price();
        uint256 tolerance = uint256(0.01 ether).mulWadDown(p);
        assertGt(cp, p - tolerance, "p too low");
        assertLt(cp, p + tolerance, "p too high");

        // Make sure total supply doesn't change
        uint256 cts = ERC20(address(flt)).totalSupply();
        assertEq(cts, ts);
    }

    /// @notice Make sure leveraging down run as expected
    function testPushDebt() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2.6 ether);
        uint256 lr = flt.leverageRatio();
        uint256 tc = flt.totalCollateral();
        uint256 td = flt.totalDebt();
        uint256 p = flt.price();
        uint256 ts = ERC20(address(flt)).totalSupply();

        // Send some collateral to contract
        (uint256 amountIn, uint256 amountOut) = getLeveragingDownInOut(flt);
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            amountIn
        );

        // Push collateral to leverage up;
        ERC20(address(flt.debt())).transfer(address(flt), amountIn);
        flt.pushd();

        // Make sure leverage ratio is up
        uint256 clr = flt.leverageRatio();
        assertGt(clr, lr - flt.step() - 0.05 ether, "too low");
        assertLt(clr, lr - flt.step() + 0.05 ether, "too high");

        // Make sure total collateral and debt is increased
        uint256 ctc = flt.totalCollateral();
        uint256 ctd = flt.totalDebt();
        assertGt(ctc, tc - (amountOut+2), "invalid tc");
        assertLt(ctc, tc - (amountOut-2), "invalid tc");
        assertEq(ctd, td - amountIn, "invalid td");

        // Make sure price doesn't change
        uint256 cp = flt.price();
        uint256 tolerance = uint256(0.01 ether).mulWadDown(p);
        assertGt(cp, p - tolerance, "p too low");
        assertLt(cp, p + tolerance, "p too high");

        // Make sure total supply doesn't change
        uint256 cts = ERC20(address(flt)).totalSupply();
        assertEq(cts, ts);
    }

    /// @notice Make sure leveraging up run as expected
    function testPushCollateralRefund() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 1.5 ether);

        // Send some collateral to contract
        (uint256 amountIn, ) = getLeveragingUpInOut(flt);
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            address(this),
            2*amountIn
        );

        // Push collateral to leverage up;
        ERC20(address(flt.collateral())).transfer(address(flt), 2*amountIn);
        flt.pushc();

        // Check balance
        uint256 balance = ERC20(address(flt.collateral())).balanceOf(address(this));
        assertEq(balance, amountIn);
    }

    /// @notice Make sure leveraging down run as expected
    function testPushDebtRefund() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2.6 ether);

        // Send some collateral to contract
        (uint256 amountIn, ) = getLeveragingDownInOut(flt);
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            2*amountIn
        );

        // Push collateral to leverage up;
        ERC20(address(flt.debt())).transfer(address(flt), 2*amountIn);
        flt.pushd();

        // Check balance
        uint256 balance = ERC20(address(flt.debt())).balanceOf(address(this));
        assertEq(balance, amountIn);
    }
}
