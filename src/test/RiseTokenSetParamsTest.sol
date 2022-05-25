// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IVM } from "./IVM.sol";

import { RiseTokenUtils } from "./RiseTokenUtils.sol";
import { fusdc, fwbtc } from "chain/Tokens.sol";

import { RiseTokenFactory } from "../RiseTokenFactory.sol";
import { RiseToken } from "../RiseToken.sol";
import { IRiseToken } from "../interfaces/IRiseToken.sol";


/**
 * @title Rise Token Set Params Test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract RiseTokenSetParamsTest {

    /// ███ Storages █████████████████████████████████████████████████████████

    IVM private immutable vm = IVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    RiseToken      private riseToken;
    RiseTokenUtils private riseTokenUtils;


    /// ███ Test Setup ███████████████████████████████████████████████████████

    function setUp() public {
        // Create RiseToken utils contract
        riseTokenUtils = new RiseTokenUtils();

        // Create new RiseToken owned by this contract
        address feeRecipient = vm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);
        riseToken = factory.create(
            fwbtc,
            fusdc,
            riseTokenUtils.uniswapAdapter(),
            riseTokenUtils.oracleAdapter()
        );
    }


    /// ███ setParams ████████████████████████████████████████████████████████

    /// @notice Make sure it revert when non-owner trying to execute
    function testSetParamsRevertIfNonOwnerExecute() public {
        // Create factory
        address feeRecipient = vm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new Rise token
        RiseToken wbtcRise = factory.create(
            fwbtc,
            fusdc,
            riseTokenUtils.uniswapAdapter(),
            riseTokenUtils.oracleAdapter()
        );

        // Transfer ownership
        address newOwner = vm.addr(2);
        wbtcRise.transferOwnership(newOwner);

        // Set params as non-owner
        vm.expectRevert("Ownable: caller is not the owner");
        wbtcRise.setParams(
            1.5 ether,
            2.5 ether,
            0.1 ether,
            0.01 ether,
            type(uint256).max
        );
    }


    /// @notice Make sure it revert when minLeverageRatio invalid
    function testSetParamsRevertIfMinLeverageRatioInvalid() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.InvalidLeverageRatio.selector
            )
        );
        riseToken.setParams(
            0 ether,
            2.5 ether,
            0.1 ether,
            0.01 ether,
            type(uint256).max
        );
    }

    /// @notice Make sure it revert when maxLeverageRatio invalid
    function testSetParamsRevertIfMaxLeverageRatioInvalid() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.InvalidLeverageRatio.selector
            )
        );
        riseToken.setParams(
            1.2 ether,
            5 ether,
            0.1 ether,
            0.01 ether,
            type(uint256).max
        );
    }

    /// @notice Make sure it revert when rebalancing step invalid
    function testSetParamsRevertIfRebalancingStepAboveMax() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.InvalidRebalancingStep.selector
            )
        );
        riseToken.setParams(
            1.2 ether,
            2.3 ether,
            0.6 ether,
            0.01 ether,
            type(uint256).max
        );
    }

    /// @notice Make sure it revert when rebalancing step invalid
    function testSetParamsRevertIfRebalancingStepBelowMin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.InvalidRebalancingStep.selector
            )
        );
        riseToken.setParams(
            1.2 ether,
            2.3 ether,
            0.001 ether,
            0.01 ether,
            type(uint256).max
        );
    }

    /// @notice Make sure it revert when discount invalid
    function testSetParamsRevertIfDiscountAboveMax() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.InvalidDiscount.selector
            )
        );
        riseToken.setParams(
            1.2 ether,
            2.3 ether,
            0.2 ether,
            1 ether,
            type(uint256).max
        );
    }

    /// @notice Make sure it revert when discount invalid
    function testSetParamsRevertIfDiscountBelowMin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.InvalidDiscount.selector
            )
        );
        riseToken.setParams(
            1.2 ether,
            2.3 ether,
            0.2 ether,
            0.001 ether,
            type(uint256).max
        );
    }

    /// @notice Make sure the storage is updated
    function testSetParams() public {
        uint256 newMinLeverageRatio = 1.5 ether;
        uint256 newMaxLeverageRatio = 2.6 ether;
        uint256 newStep = 0.2 ether;
        uint256 newDiscount = 0.01 ether;
        uint256 newMaxBuy = 10;

        // Set params
        riseToken.setParams(
            newMinLeverageRatio,
            newMaxLeverageRatio,
            newStep,
            newDiscount,
            newMaxBuy
        );

        // Check storages
        require(
            riseToken.minLeverageRatio() == newMinLeverageRatio,
            "invalid minLeverageRatio"
        );
        require(
            riseToken.maxLeverageRatio() == newMaxLeverageRatio,
            "invalid maxLeverageRatio"
        );
        require(riseToken.step() == newStep, "invalid step");
        require(riseToken.discount() == newDiscount, "invalid discount");
        require(riseToken.maxBuy() == newMaxBuy, "invalid max buy");
    }
}
