// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { IFLT } from "../src/interfaces/IFLT.sol";
import { FLTRebalancer } from "../src/FLTRebalancer.sol";

import { BaseTest } from "./BaseTest.sol";

abstract contract BaseRebalancerTest is BaseTest {

    using FixedPointMathLib for uint256;

    /// @notice Make sure revert if input length is not equal
    function testRebalancerGetRebalancesRevertIfInputInvalid() public {
        // Deploy rebalancer
        address recipient = vm.addr(1);
        FLTRebalancer rebalancer = new FLTRebalancer(recipient);

        address[] memory flts = new address[](2);
        flts[0] = vm.addr(2);
        flts[1] = vm.addr(3);

        uint256[] memory profits = new uint256[](1);
        profits[0] = 1 ether;

        vm.expectRevert("INVALID");
        rebalancer.getRebalances(flts, profits);
    }

    /// @notice Make sure it returns empty bytes if flt is in range
    function testRebalancerGetRebalancesReturnZeroIfLeverageRatioInRange() public {
        // Deploy flt
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);

        // Deploy rebalancer
        address recipient = vm.addr(1);
        FLTRebalancer rebalancer = new FLTRebalancer(recipient);

        address[] memory flts = new address[](1);
        flts[0] = address(flt);
        uint256[] memory profits = new uint256[](1);
        profits[0] = 1 ether;

        bytes[] memory calls = rebalancer.getRebalances(flts, profits);
        assertEq(calls.length, 1, "invalid length");
        assertEq(calls[0], "", "invalid value");
    }

    /// @notice Make sure it returns correct calls data
    function testRebalancerGetRebalancesReturnZeroIfMinProfitTooHigh() public {
        // Deploy flt
        Data memory data = getData();
        IFLT flt1 = deployAndInitialize(data, 1.6 ether);
        IFLT flt2 = deployAndInitialize(data, 2.6 ether);

        // Deploy rebalancer
        address recipient = vm.addr(1);
        FLTRebalancer rebalancer = new FLTRebalancer(recipient);

        address[] memory flts = new address[](2);
        flts[0] = address(flt1);
        flts[1] = address(flt2);
        uint256[] memory profits = new uint256[](2);
        profits[0] = 1000 ether;
        profits[1] = 1000 ether;

        bytes[] memory calls = rebalancer.getRebalances(flts, profits);
        assertEq(calls.length, 2, "invalid length");
        assertEq(calls[0], "", "invalid value");
        assertEq(calls[1], "", "invalid value");
    }

    /// @notice Make sure it returns correct calls data
    function testRebalancerGetRebalancesReturnCorrectCalldata() public {
        // Deploy flt
        Data memory data = getData();
        IFLT flt1 = deployAndInitialize(data, 1.6 ether);
        IFLT flt2 = deployAndInitialize(data, 2.6 ether);

        // Deploy rebalancer
        address recipient = vm.addr(1);
        FLTRebalancer rebalancer = new FLTRebalancer(recipient);

        address[] memory flts = new address[](2);
        flts[0] = address(flt1);
        flts[1] = address(flt2);
        uint256[] memory profits = new uint256[](2);
        profits[0] = 0.005 ether;
        profits[1] = 0.005 ether;

        bytes[] memory calls = rebalancer.getRebalances(flts, profits);
        assertEq(calls.length, 2, "invalid length");
        assertEq(
            calls[0],
            abi.encodeWithSelector(
                FLTRebalancer.leverageUp.selector,
                address(flt1),
                0.005 ether
            ),
            "invalid leverage up"
        );
        assertEq(
            calls[1],
            abi.encodeWithSelector(
                FLTRebalancer.leverageDown.selector,
                address(flt2),
                0.005 ether
            ),
            "invalid leverage down"
        );
    }

    /// @notice Make sure it can execute multiple rebalance
    function testRebalancerMulticall() public {
        // Deploy flt
        Data memory data = getData();
        IFLT flt1 = deployAndInitialize(data, 1.6 ether);
        IFLT flt2 = deployAndInitialize(data, 2.6 ether);

        // Deploy rebalancer
        address recipient = vm.addr(1);
        FLTRebalancer rebalancer = new FLTRebalancer(recipient);

        // Reset profit recipient balance
        setBalance(
            address(flt1.debt()),
            data.debtSlot,
            recipient,
            0
        );
        setBalance(
            address(flt1.collateral()),
            data.collateralSlot,
            recipient,
            0
        );

        address[] memory flts = new address[](2);
        flts[0] = address(flt1);
        flts[1] = address(flt2);
        uint256[] memory profits = new uint256[](2);
        profits[0] = 0.005 ether;
        profits[1] = 0.005 ether;

        bytes[] memory calls = rebalancer.getRebalances(flts, profits);
        rebalancer.multicall(calls);

        // Check the leverage ratio
        assertGt(flt1.leverageRatio(), 1.5 ether, "leverage up failed");
        assertLt(flt2.leverageRatio(), 2.5 ether, "leverage down failed");

        // Check recipient balance
        assertGt(
            ERC20(address(flt1.collateral())).balanceOf(recipient),
            0,
            "invalid collateral balance"
        );
        assertGt(
            ERC20(address(flt1.debt())).balanceOf(recipient),
            0,
            "invalid debt balance"
        );
    }

}
