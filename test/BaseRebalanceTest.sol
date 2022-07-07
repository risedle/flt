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
    function testPushCollateralRevertIfAmountInGreaterThanMaxSwapAmount() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 1.5 ether);

        // Send some collateral to contract
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            address(this),
            1_000 ether
        );
        ERC20(address(flt.collateral())).transfer(address(flt), 1_000 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountOutTooHigh.selector
            )
        );
        flt.pushc();
    }

    /// @notice Make sure leveraging down revert if amount in less than min
    function testPushDebtRevertIfAmountInGreaterThanMaxSwapAmount() public {
        // Deploy and initialize 2.6 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2.6 ether);

        // Send some collateral to contract
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            1_000_000 ether
        );
        ERC20(address(flt.debt())).transfer(address(flt), 1_000_000 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountOutTooHigh.selector
            )
        );
        flt.pushd();
    }

    /// @notice Make sure leveraging up run as expected
    function testPushCollateral() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 1.65 ether);
        uint256 lr = flt.leverageRatio();
        uint256 tc = flt.totalCollateral();
        uint256 td = flt.totalDebt();
        uint256 p = flt.price();
        uint256 ts = ERC20(address(flt)).totalSupply();

        // Send some collateral to contract
        address rebalancer = vm.addr(2);
        startHoax(rebalancer);
        uint256 amountIn = 0.005 ether;
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            rebalancer,
            amountIn
        );
        uint256 amountOut = flt.oracleAdapter().totalValue(
            address(flt.collateral()),
            address(flt.debt()),
            amountIn
        );

        // Push collateral to leverage up;
        ERC20(address(flt.collateral())).transfer(address(flt), amountIn);
        (uint256 received, uint256 incentive) = flt.pushc();

        // Make sure received is correct
        assertEq(received, amountOut + incentive, "invalid received");

        // Make sure incentive is correct
        assertGt(incentive, 0, "incentive too low");
        // 1.6 min; 0.4 max drift; 0.2 max incentive;
        // when lr = 1.5, the incentives should be 0.05 or 5%
        uint256 maxIncentive = uint256(0.05 ether).mulWadDown(amountOut); // 5%
        assertLt(incentive, maxIncentive + 2, "incentive too high");
        assertGt(incentive, maxIncentive - 2, "incentive too low");

        // Make sure leverage ratio is up
        assertGt(flt.leverageRatio(), lr, "too low");

        // Make sure total collateral and debt is increased
        uint256 ctc = flt.totalCollateral();
        uint256 ctd = flt.totalDebt();
        assertEq(ctc, tc + amountIn, "invalid tc");
        assertEq(ctd, td + received, "invalid td");

        // Make sure price doesn't change
        uint256 tolerance = uint256(0.01 ether).mulWadDown(p);
        assertGt(flt.price(), p - tolerance, "p too low");
        assertLt(flt.price(), p + tolerance, "p too high");

        // Make sure total supply doesn't change
        assertEq(ERC20(address(flt)).totalSupply(), ts);

        // Rebalancer receive the token
        assertEq(
            ERC20(address(flt.debt())).balanceOf(rebalancer),
            received,
            "invalid rebalancer"
        );
    }

    /// @notice Make sure leveraging down run as expected
    function testPushDebt() public {
        // Deploy and initialize 2.6 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2.6 ether);
        uint256 lr = flt.leverageRatio();
        uint256 tc = flt.totalCollateral();
        uint256 td = flt.totalDebt();
        uint256 p = flt.price();
        uint256 ts = ERC20(address(flt)).totalSupply();

        // Send some collateral to contract
        address rebalancer = vm.addr(2);
        startHoax(rebalancer);
        uint256 amountIn = 0.005 ether;
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            rebalancer,
            amountIn
        );
        uint256 amountOut = flt.oracleAdapter().totalValue(
            address(flt.debt()),
            address(flt.collateral()),
            amountIn
        );

        // Push collateral to leverage up;
        ERC20(address(flt.debt())).transfer(address(flt), amountIn);
        (uint256 received, uint256 incentive) = flt.pushd();

        // Make sure received is correct
        assertEq(received, amountOut + incentive, "invalid received");

        // Make sure incentive is correct
        assertGt(incentive, 0, "incentive too low");
        // 2.5 max; 0.4 max drift; 0.2 max incentive;
        // when lr = 2.6, the incentives should be 0.05 or 5%
        uint256 maxIncentive = uint256(0.05 ether).mulWadDown(amountOut); // 5%
        assertLt(incentive, maxIncentive + 3, "incentive too high");
        assertGt(incentive, maxIncentive - 3, "incentive too low");

        // Make sure leverage ratio is up
        assertLt(flt.leverageRatio(), lr, "too high");

        // Make sure total collateral and debt is decreased
        uint256 ctc = flt.totalCollateral();
        uint256 ctd = flt.totalDebt();
        assertGt(ctc, (tc - received) - 2, "tc too low");
        assertLt(ctc, (tc - received) + 2, "tc too high");
        assertEq(ctd, td - amountIn, "invalid td");

        // Make sure price doesn't change
        uint256 tolerance = uint256(0.01 ether).mulWadDown(p);
        assertGt(flt.price(), p - tolerance, "p too low");
        assertLt(flt.price(), p + tolerance, "p too high");

        // Make sure total supply doesn't change
        assertEq(ERC20(address(flt)).totalSupply(), ts);

        // Rebalancer receive the token
        assertEq(
            ERC20(address(flt.collateral())).balanceOf(rebalancer),
            received,
            "invalid rebalancer"
        );
    }
}
