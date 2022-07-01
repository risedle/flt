// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { RiseToken } from "../src/RiseToken.sol";
import { IRiseToken } from "../src/interfaces/IRiseToken.sol";

import { BaseTest } from "./BaseTest.sol";

abstract contract BaseRebalanceTest is BaseTest {

    using FixedPointMathLib for uint256;

    /// @notice Make sure leverage up revert if leverage ratio in range
    function testPushCollateralRevertIfLeverageRatioInRange() public {
        // Deploy and initialize 2x leverage ratio
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.Balance.selector
            )
        );
        riseToken.pushc();
    }

    /// @notice Make sure leverage down revert if leverage ratio in range
    function testPushDebtRevertIfLeverageRatioInRange() public {
        // Deploy and initialize 2x leverage ratio
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.Balance.selector
            )
        );
        riseToken.pushd();
    }

    /// @notice Make sure leveraging up revert if no collateral send
    function testPushCollateralRevertIfAmountInIsZero() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 1.5 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountInTooLow.selector
            )
        );
        riseToken.pushc();
    }

    /// @notice Make sure leveraging down revert if no debt send
    function testPushDebtRevertIfAmountInIsZero() public {
        // Deploy and initialize 2.6 leverage ratio
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2.6 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountInTooLow.selector
            )
        );
        riseToken.pushd();
    }

    /// @notice Make sure leveraging up revert if amount in less than min
    function testPushCollateralRevertIfAmountInLessThanMinAmountIn() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 1.5 ether);

        // Send some collateral to contract
        setBalance(
            address(data.collateral),
            data.collateralSlot,
            address(this),
            0.01 ether
        );
        data.collateral.transfer(address(riseToken), 0.01 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountInTooLow.selector
            )
        );
        riseToken.pushc();
    }

    /// @notice Make sure leveraging down revert if amount in less than min
    function testPushDebtRevertIfAmountInLessThanMinAmountIn() public {
        // Deploy and initialize 2.6 leverage ratio
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2.6 ether);

        // Send some collateral to contract
        setBalance(
            address(data.debt),
            data.debtSlot,
            address(this),
            0.01 ether
        );
        data.debt.transfer(address(riseToken), 0.01 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountInTooLow.selector
            )
        );
        riseToken.pushd();
    }

    /// @notice Make sure leveraging up run as expected
    function testPushCollateral() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 1.5 ether);
        uint256 lr = riseToken.leverageRatio();
        uint256 tc = riseToken.totalCollateral();
        uint256 td = riseToken.totalDebt();
        uint256 p = riseToken.price();
        uint256 ts = riseToken.totalSupply();

        // Send some collateral to contract
        (uint256 amountIn, uint256 amountOut) = getLeveragingUpInOut(riseToken);
        setBalance(
            address(data.collateral),
            data.collateralSlot,
            address(this),
            amountIn
        );

        // Push collateral to leverage up;
        data.collateral.transfer(address(riseToken), amountIn);
        riseToken.pushc();

        // Make sure leverage ratio is up
        uint256 clr = riseToken.leverageRatio();
        assertGt(clr, lr + riseToken.step() - 0.05 ether, "too low");
        assertLt(clr, lr + riseToken.step() + 0.05 ether, "too high");

        // Make sure total collateral and debt is increased
        uint256 ctc = riseToken.totalCollateral();
        uint256 ctd = riseToken.totalDebt();
        assertEq(ctc, tc + amountIn, "invalid tc");
        assertEq(ctd, td + amountOut, "invalid td");

        // Make sure price doesn't change
        uint256 cp = riseToken.price();
        uint256 tolerance = uint256(0.01 ether).mulWadDown(p);
        assertGt(cp, p - tolerance, "p too low");
        assertLt(cp, p + tolerance, "p too high");

        // Make sure total supply doesn't change
        uint256 cts = riseToken.totalSupply();
        assertEq(cts, ts);
    }

    /// @notice Make sure leveraging down run as expected
    function testPushDebt() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2.6 ether);
        uint256 lr = riseToken.leverageRatio();
        uint256 tc = riseToken.totalCollateral();
        uint256 td = riseToken.totalDebt();
        uint256 p = riseToken.price();
        uint256 ts = riseToken.totalSupply();

        // Send some collateral to contract
        (uint256 amountIn, uint256 amountOut) = getLeveragingDownInOut(riseToken);
        setBalance(
            address(data.debt),
            data.debtSlot,
            address(this),
            amountIn
        );

        // Push collateral to leverage up;
        data.debt.transfer(address(riseToken), amountIn);
        riseToken.pushd();

        // Make sure leverage ratio is up
        uint256 clr = riseToken.leverageRatio();
        assertGt(clr, lr - riseToken.step() - 0.05 ether, "too low");
        assertLt(clr, lr - riseToken.step() + 0.05 ether, "too high");

        // Make sure total collateral and debt is increased
        uint256 ctc = riseToken.totalCollateral();
        uint256 ctd = riseToken.totalDebt();
        assertEq(ctc, tc - amountOut, "invalid tc");
        assertEq(ctd, td - amountIn, "invalid td");

        // Make sure price doesn't change
        uint256 cp = riseToken.price();
        uint256 tolerance = uint256(0.01 ether).mulWadDown(p);
        assertGt(cp, p - tolerance, "p too low");
        assertLt(cp, p + tolerance, "p too high");

        // Make sure total supply doesn't change
        uint256 cts = riseToken.totalSupply();
        assertEq(cts, ts);
    }

    /// @notice Make sure leveraging up run as expected
    function testPushCollateralRefund() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 1.5 ether);

        // Send some collateral to contract
        (uint256 amountIn, ) = getLeveragingUpInOut(riseToken);
        setBalance(
            address(data.collateral),
            data.collateralSlot,
            address(this),
            2*amountIn
        );

        // Push collateral to leverage up;
        data.collateral.transfer(address(riseToken), 2*amountIn);
        riseToken.pushc();

        // Check balance
        uint256 balance = data.collateral.balanceOf(address(this));
        assertEq(balance, amountIn);
    }

    /// @notice Make sure leveraging down run as expected
    function testPushDebtRefund() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2.6 ether);

        // Send some collateral to contract
        (uint256 amountIn, ) = getLeveragingDownInOut(riseToken);
        setBalance(
            address(data.debt),
            data.debtSlot,
            address(this),
            2*amountIn
        );

        // Push collateral to leverage up;
        data.debt.transfer(address(riseToken), 2*amountIn);
        riseToken.pushd();

        // Check balance
        uint256 balance = data.debt.balanceOf(address(this));
        assertEq(balance, amountIn);
    }
}
