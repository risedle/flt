// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { RiseToken } from "../src/RiseToken.sol";
import { IRiseToken } from "../src/interfaces/IRiseToken.sol";

import { BaseTest } from "./BaseTest.sol";

abstract contract BaseRebalanceTest is BaseTest {

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
}
