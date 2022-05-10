// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IVM } from "./IVM.sol";
import { VMUtils } from "./VMUtils.sol";

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { RiseToken } from "../RiseToken.sol";
import { IRiseToken } from "../interfaces/IRiseToken.sol";
import { RiseTokenPeriphery } from "../RiseTokenPeriphery.sol";

import { RiseTokenUtils } from "./RiseTokenUtils.sol";

/**
 * @title Rise Token Rebalancing Test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract RiseTokenRebalancingTest {

    /// ███ Libraries ████████████████████████████████████████████████████████

    using FixedPointMathLib for uint256;


    /// ███ Storages █████████████████████████████████████████████████████████

    IVM private immutable vm = IVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    VMUtils                    private utils;
    RiseTokenPeriphery         private periphery;
    RiseTokenUtils             private riseTokenUtils;


    /// ███ Test Setup ███████████████████████████████████████████████████████

    function setUp() public {
        // Create utils
        utils = new VMUtils(vm);

        // Create periphery
        periphery = new RiseTokenPeriphery();

        // Create Rise Token Utils
        riseTokenUtils = new RiseTokenUtils();

    }


    /// ███ Push █████████████████████████████████████████████████████████████

    /// @notice Make sure push is reverted when leverage ratio in range
    function testPushRevertIfLeverageRatioInRrange() public {
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.NoNeedToRebalance.selector
            )
        );
        wbtcRise.push(1e8); // should be reverted
    }

    /// @notice Make sure it revert when trying to push large amount
    function testPushRevertIfAmountInIsTooLarge() public {
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 1.6 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.SwapAmountTooLarge.selector
            )
        );
        wbtcRise.push(10*1e8);
    }

    /// @notice Make sure it returns early if input is zero
    function testPushReturnZeroIfInputIsZero() public {
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 1.6 ether);
        require(wbtcRise.push(0) == 0, "invalid return");
    }

    /// @notice Make sure it can swap if pushed amount is max
    function testPushMaxAmount() public {
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 1.6 ether);
        ERC20 collateral = wbtcRise.collateral();
        ERC20 debt = wbtcRise.debt();
        uint256 maxAmountIn = periphery.getMaxPush(wbtcRise);
        uint256 amountOut = periphery.previewPush(wbtcRise, maxAmountIn);

        // Set contract balance
        utils.setWBTCBalance(address(this), maxAmountIn);

        // Approve
        collateral.approve(address(wbtcRise), maxAmountIn);

        // Storages before push
        uint256 tc = wbtcRise.totalCollateral();
        uint256 td = wbtcRise.totalDebt();
        uint256 p = wbtcRise.nav();
        uint256 cps = wbtcRise.collateralPerShare();
        uint256 dps = wbtcRise.debtPerShare();

        // Push collateral to Rise Token
        require(wbtcRise.push(maxAmountIn) == amountOut, "invalid amountOut");

        // Check balance after push
        require(collateral.balanceOf(address(this)) == 0, "wbtc balance after push");
        require(debt.balanceOf(address(this)) == amountOut, "usdc balance after push");

        // Make sure the leverage ratio is increased
        require(wbtcRise.leverageRatio() > 1.6 ether, "invalid lr");
        require(wbtcRise.leverageRatio() < 2 ether, "invalid lr");

        // Total collateral and total debt should increased
        require(wbtcRise.totalCollateral() > tc, "invalid total collateral");
        require(wbtcRise.totalDebt() > td, "invalid total debt");
        require(wbtcRise.collateralPerShare() > cps, "invalid cps");
        require(wbtcRise.debtPerShare() > dps, "invalid dps");

        // Price sillpage shouldn't too high
        require(wbtcRise.nav() > (p - 1e6), "invalid price");
        require(wbtcRise.nav() < (p + 1e6), "invalid price");
    }

    /// @notice Make sure it can swap if pushed amount is max
    function testPushLessThanMaxAmount() public {
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 1.6 ether);
        ERC20 collateral = wbtcRise.collateral();
        uint256 maxAmountIn = periphery.getMaxPush(wbtcRise);
        uint256 amountIn = uint256(0.3 ether).mulWadDown(maxAmountIn);
        uint256 amountOut = periphery.previewPush(wbtcRise, amountIn);

        // Set contract balance
        utils.setWBTCBalance(address(this), maxAmountIn);

        // Approve
        collateral.approve(address(wbtcRise), maxAmountIn);

        // Storages before push
        uint256 lr = wbtcRise.leverageRatio();
        uint256 tc = wbtcRise.totalCollateral();
        uint256 td = wbtcRise.totalDebt();
        uint256 p = wbtcRise.nav();
        uint256 cps = wbtcRise.collateralPerShare();
        uint256 dps = wbtcRise.debtPerShare();

        // Push collateral to Rise Token
        require(wbtcRise.push(amountIn) == amountOut, "invalid amountOut");

        // Check leverage ratio
        require(wbtcRise.leverageRatio() > 1.6 ether, "invalid lr");
        require(wbtcRise.leverageRatio() < 1.6 ether + wbtcRise.step(), "invalid lr");

        // Total collateral and debt should increased
        require(wbtcRise.totalCollateral() > tc, "invalid total collateral");
        require(wbtcRise.totalDebt() > td, "invalid total debt");
        require(wbtcRise.collateralPerShare() > cps, "invalid cps");
        require(wbtcRise.debtPerShare() > dps, "invalid dps");

        // Price slippage shouldn't be too high
        require(wbtcRise.nav() > (p - 1e6), "invalid price");
        require(wbtcRise.nav() < (p + 1e6), "invalid price");

        // Push for second time
        lr = wbtcRise.leverageRatio();
        tc = wbtcRise.totalCollateral();
        td = wbtcRise.totalDebt();
        p = wbtcRise.nav();
        cps = wbtcRise.collateralPerShare();
        dps = wbtcRise.debtPerShare();

        // Push collateral to Rise Token
        require(wbtcRise.push(amountIn) == amountOut, "2nd invalid amountOut");

        // Check leverage ratio
        require(wbtcRise.leverageRatio() > lr, "2nd invalid lr");
        require(wbtcRise.leverageRatio() < 1.6 ether + wbtcRise.step(), "2nd invalid lr");

        // Total collateral should be increased
        require(wbtcRise.totalCollateral() > tc, "2nd invalid total collateral");
        require(wbtcRise.totalDebt() > td, "2nd invalid total debt");
        require(wbtcRise.collateralPerShare() > cps, "2nd invalid cps");
        require(wbtcRise.debtPerShare() > dps, "2nd invalid dps");

        // Price slippage shouldn't be too high
        require(wbtcRise.nav() > (p - 1e6), "2nd invalid price");
        require(wbtcRise.nav() < (p + 1e6), "2nd invalid price");
    }


    /// ███ Pull █████████████████████████████████████████████████████████████

    /// @notice Make sure push is reverted when leverage ratio in range
    function testPullRevertIfLeverageRatioInRrange() public {
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.NoNeedToRebalance.selector
            )
        );
        wbtcRise.pull(1e8); // should be reverted
    }

    /// @notice Make sure it revert when trying to pull large amount
    function testPullRevertIfAmountOutIsTooLarge() public {
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2.8 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.SwapAmountTooLarge.selector
            )
        );
        wbtcRise.pull(10*1e8);
    }

    /// @notice Make sure it returns early if input is zero
    function testPullReturnZeroIfInputIsZero() public {
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2.8 ether);
        require(wbtcRise.pull(0) == 0, "invalid return");
    }

    /// @notice Make sure it can push with max amount
    function testPullMaxAmount() public {
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2.6 ether);
        ERC20 collateral = wbtcRise.collateral();
        ERC20 debt = wbtcRise.debt();
        uint256 maxAmountOut = periphery.getMaxPull(wbtcRise);
        uint256 amountIn = periphery.previewPull(wbtcRise, maxAmountOut);

        // Set contract balance
        utils.setUSDCBalance(address(this), amountIn);

        // Approve
        debt.approve(address(wbtcRise), amountIn);

        // Storages before push
        uint256 tc = wbtcRise.totalCollateral();
        uint256 td = wbtcRise.totalDebt();
        uint256 p = wbtcRise.nav();
        uint256 cps = wbtcRise.collateralPerShare();
        uint256 dps = wbtcRise.debtPerShare();

        // Pull collateral to Rise Token
        require(wbtcRise.pull(maxAmountOut) == amountIn, "invalid amountIn");

        // Check balance after push
        require(debt.balanceOf(address(this)) == 0, "usdc balance after pull");
        require(collateral.balanceOf(address(this)) == maxAmountOut, "wbtc balance after pull");

        // Make sure the leverage ratio is decreased
        require(wbtcRise.leverageRatio() < 2.5 ether, "invalid lr");
        require(wbtcRise.leverageRatio() > 2 ether, "invalid lr");

        // Make sure total collateral and debt is decreased
        require(wbtcRise.totalCollateral() < tc, "invalid total collateral");
        require(wbtcRise.totalDebt() < td, "invalid total debt");
        require(wbtcRise.collateralPerShare() < cps, "invalid cps");
        require(wbtcRise.debtPerShare() < dps, "invalid dps");

        // Make sure the price slippage is not too high
        require(wbtcRise.nav() > (p - 1e6), "invalid price");
        require(wbtcRise.nav() < (p + 1e6), "invalid price");
    }

    /// @notice Make sure it can be pulled twice
    function testPullLessThanMaxAmount() public {
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2.6 ether);
        ERC20 collateral = wbtcRise.collateral();
        ERC20 debt = wbtcRise.debt();
        uint256 maxAmountOut = periphery.getMaxPull(wbtcRise);
        uint256 amountOut = uint256(0.3 ether).mulWadDown(maxAmountOut);
        uint256 amountIn = periphery.previewPull(wbtcRise, amountOut);

        // Set contract balance
        utils.setUSDCBalance(address(this), amountIn);

        // Approve
        debt.approve(address(wbtcRise), amountIn);

        // Storages before push
        uint256 lr = wbtcRise.leverageRatio();
        uint256 tc = wbtcRise.totalCollateral();
        uint256 td = wbtcRise.totalDebt();
        uint256 p = wbtcRise.nav();
        uint256 cps = wbtcRise.collateralPerShare();
        uint256 dps = wbtcRise.debtPerShare();

        // Push collateral to Rise Token
        require(wbtcRise.pull(amountOut) == amountIn, "invalid amountIn");

        // Check balance after push
        require(debt.balanceOf(address(this)) == 0, "usdc balance after pull");
        require(collateral.balanceOf(address(this)) == amountOut, "wbtc balance after pull");

        // Leverage ratio should be decreased
        require(wbtcRise.leverageRatio() < lr, "invalid lr");
        require(wbtcRise.leverageRatio() > 2.6 ether - wbtcRise.step(), "invalid lr");

        // Total collateral and total debt should be decreased
        require(wbtcRise.totalCollateral() < tc, "invalid total collateral");
        require(wbtcRise.totalDebt() < td, "invalid total debt");
        require(wbtcRise.collateralPerShare() < cps, "invalid cps");
        require(wbtcRise.debtPerShare() < dps, "invalid dps");

        // Make sure price slippage is not too high
        require(wbtcRise.nav() > (p - 1e6), "invalid price");
        require(wbtcRise.nav() < (p + 1e6), "invalid price");

        // Pull for the second time
        lr = wbtcRise.leverageRatio();
        tc = wbtcRise.totalCollateral();
        td = wbtcRise.totalDebt();
        p = wbtcRise.nav();
        cps = wbtcRise.collateralPerShare();
        dps = wbtcRise.debtPerShare();

        // Set contract balance
        utils.setUSDCBalance(address(this), amountIn);
        debt.approve(address(wbtcRise), amountIn);

        // Push collateral to Rise Token
        require(wbtcRise.pull(amountOut) == amountIn, "2nd invalid amountIn");

        // Check balance after push
        require(debt.balanceOf(address(this)) == 0, "usdc balance after pull");
        require(collateral.balanceOf(address(this)) == amountOut*2, "2nd wbtc balance after pull");

        // Leverage ratio should be decreased
        require(wbtcRise.leverageRatio() < lr, "invalid lr");
        require(wbtcRise.leverageRatio() > 2.6 ether - wbtcRise.step(), "invalid lr");

        // Total collateral and total debt should be decreased
        require(wbtcRise.totalCollateral() < tc, "invalid total collateral");
        require(wbtcRise.totalDebt() < td, "invalid total debt");
        require(wbtcRise.collateralPerShare() < cps, "invalid cps");
        require(wbtcRise.debtPerShare() < dps, "invalid dps");

        // Make sure price slippage is not too high
        require(wbtcRise.nav() > (p - 1e6), "invalid price");
        require(wbtcRise.nav() < (p + 1e6), "invalid price");
    }

}
