// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { RiseToken } from "../src/RiseToken.sol";
import { IRiseToken } from "../src/interfaces/IRiseToken.sol";

import { BaseTest } from "./BaseTest.sol";

abstract contract BaseBurnTest is BaseTest {

    using FixedPointMathLib for uint256;

    /// @notice Make sure it revert when token is not initialized
    function testBurnRevertIfNotInitializedViaDebt() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        RiseToken riseToken = deploy(data);

        // MintFromDebt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.Uninitialized.selector
            )
        );
        riseToken.burnd(address(this), 0);
    }

    /// @notice Make sure it revert when token is not initialized
    function testBurnRevertIfNotInitializedViaCollateral() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        RiseToken riseToken = deploy(data);

        // MintFromDebt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.Uninitialized.selector
            )
        );
        riseToken.burnc(address(this), 0);
    }

    /// @notice Make sure it revert when burn amount is zero
    function testBurnRevertIfBurnAmountIsZeroViaDebt() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // Burn to debt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountInTooLow.selector
            )
        );
        riseToken.burnd(address(this), 0);
    }

    /// @notice Make sure it revert when burn amount is zero
    function testBurnRevertIfBurnAmountIsZeroViaCollateral() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // Burn to collateral; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountInTooLow.selector
            )
        );
        riseToken.burnc(address(this), 0);
    }

    /// @notice Make sure it revert if amount out less than min amount out
    function testBurnRevertIfAmountOutLessThanMinAmountOutViaDebt() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // Mint first
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;
        uint256 amountIn = getAmountIn(
            riseToken,
            mintAmount,
            address(data.debt)
        );
        setBalance(address(data.debt), data.debtSlot, minter, amountIn);
        data.debt.transfer(address(riseToken), amountIn);
        riseToken.mintd(mintAmount, minter, minter);

        // Transfer token to burn
        riseToken.transfer(address(riseToken), mintAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountOutTooLow.selector
            )
        );
        riseToken.burnd(address(this), 1e18 ether);
    }

    /// @notice Make sure it revert if amount out less than min amount out
    function testBurnRevertIfAmountOutLessThanMinAmountOutViaCollateral() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // Mint first
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;
        uint256 amountIn = getAmountIn(
            riseToken,
            mintAmount,
            address(data.collateral)
        );
        setBalance(
            address(data.collateral),
            data.collateralSlot,
            minter,
            amountIn
        );
        data.collateral.transfer(address(riseToken), amountIn);
        riseToken.mintc(mintAmount, minter, minter);

        // Transfer to burn
        riseToken.transfer(address(riseToken), mintAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountOutTooLow.selector
            )
        );
        riseToken.burnc(address(this), 1e18 ether);
    }

    /// @notice Make sure burn doesn't change the price
    function testBurnWithLeverageRatioViaDebt(uint256 _lr) internal {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, _lr);

        // Reset fee recipient balance to zero
        setBalance(
            address(data.debt),
            data.debtSlot,
            data.factory.feeRecipient(),
            0
        );

        // Mint
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;
        uint256 amountIn = getAmountIn(
            riseToken,
            mintAmount,
            address(data.debt)
        );
        setBalance(address(data.debt), data.debtSlot, minter, amountIn);
        data.debt.transfer(address(riseToken), amountIn);
        riseToken.mintd(mintAmount, minter, minter);

        // Make sure these values does not change after burn
        uint256 cps = riseToken.collateralPerShare();
        uint256 dps = riseToken.debtPerShare();
        uint256 price = riseToken.price();
        uint256 lr  = riseToken.leverageRatio();
        uint256 fb = data.debt.balanceOf(data.factory.feeRecipient());

        // Make sure these values is decreased after burn
        uint256 ts = riseToken.totalSupply();

        // Burn
        riseToken.transfer(address(riseToken), mintAmount);
        riseToken.burnd(minter, 0);

        // Check minter balance
        assertEq(riseToken.balanceOf(minter), 0, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
        assertEq(riseToken.price(), price, "invalid price");
        uint256 currentLR = riseToken.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is decreased
        assertEq(riseToken.totalSupply(), ts - mintAmount, "invalid ts");

        // Make sure fee recipient receive 0.1%x2 of amountIn
        assertGt(
            data.debt.balanceOf(data.factory.feeRecipient()),
            fb,
            "invalid fee recipient"
        );
        assertEq(
            data.collateral.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );

        // Make sure there are no tokens inside contract
        assertEq(
            data.debt.balanceOf(address(riseToken)),
            0,
            "invalid debt contract balance"
        );
        assertEq(
            data.collateral.balanceOf(address(riseToken)),
            0,
            "invalid collateral contract balance"
        );
    }

    /// @notice Make sure burn doesn't change the price
    function testBurnWithLeverageRatioViaCollateral(uint256 _lr) internal {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, _lr);

        // Reset fee recipient balance to zero
        setBalance(
            address(data.collateral),
            data.collateralSlot,
            data.factory.feeRecipient(),
            0
        );

        // Mint
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;
        uint256 amountIn = getAmountIn(
            riseToken,
            mintAmount,
            address(data.collateral)
        );
        setBalance(
            address(data.collateral),
            data.collateralSlot,
            minter,
            amountIn
        );
        data.collateral.transfer(address(riseToken), amountIn);
        riseToken.mintc(mintAmount, minter, minter);

        // Make sure these values does not change after burn
        uint256 cps = riseToken.collateralPerShare();
        uint256 dps = riseToken.debtPerShare();
        uint256 price = riseToken.price();
        uint256 lr  = riseToken.leverageRatio();
        uint256 fb = data.debt.balanceOf(data.factory.feeRecipient());

        // Make sure these values is decreased after burn
        uint256 ts = riseToken.totalSupply();

        // Burn
        riseToken.transfer(address(riseToken), mintAmount);
        riseToken.burnc(minter, 0);

        // Check minter balance
        assertEq(riseToken.balanceOf(minter), 0, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
        assertEq(riseToken.price(), price, "invalid price");
        uint256 currentLR = riseToken.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is decreased
        assertEq(riseToken.totalSupply(), ts - mintAmount, "invalid ts");

        // Make sure fee recipient receive 0.1%x2 of amountIn
        assertGt(
            data.collateral.balanceOf(data.factory.feeRecipient()),
            fb,
            "invalid fee recipient"
        );
        assertEq(
            data.debt.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );

        // Make sure there are no tokens inside contract
        assertEq(
            data.debt.balanceOf(address(riseToken)),
            0,
            "invalid debt contract balance"
        );
        assertEq(
            data.collateral.balanceOf(address(riseToken)),
            0,
            "invalid collateral contract balance"
        );
    }

    function testBurnWithLeverageRatio2xViaDebt() public {
        testBurnWithLeverageRatioViaDebt(2 ether);
    }

    function testBurnWithLeverageRatio2xViaCollateral() public {
        testBurnWithLeverageRatioViaCollateral(2 ether);
    }

    function testBurnWithLeverageRatioLessThan2xViaDebt() public {
        testBurnWithLeverageRatioViaDebt(1.6 ether);
    }

    function testBurnWithLeverageRatioLessThan2xViaCollateral() public {
        testBurnWithLeverageRatioViaCollateral(1.6 ether);
    }

    function testBurnWithLeverageRatioGreaterThan2xViaDebt() public {
        testBurnWithLeverageRatioViaDebt(2.5 ether);
    }

    function testBurnWithLeverageRatioGreaterThan2xViaCollateral() public {
        testBurnWithLeverageRatioViaCollateral(2.5 ether);
    }

    /// @notice Make sure burn twice in a row doesn't change the price
    function testBurnTwiceViaDebt() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(data.debt),
            data.debtSlot,
            data.factory.feeRecipient(),
            0
        );

        // Mint
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;
        uint256 amountIn = getAmountIn(
            riseToken,
            mintAmount,
            address(data.debt)
        );
        setBalance(address(data.debt), data.debtSlot, minter, amountIn);
        data.debt.transfer(address(riseToken), amountIn);
        riseToken.mintd(mintAmount, minter, minter);

        // Make sure these values does not change after burn
        uint256 cps = riseToken.collateralPerShare();
        uint256 dps = riseToken.debtPerShare();
        uint256 price = riseToken.price();
        uint256 lr  = riseToken.leverageRatio();

        // Make sure these values is decreased after burn
        uint256 ts = riseToken.totalSupply();

        // Burn
        uint256 half = uint256(0.5 ether).mulWadDown(mintAmount);
        uint256 left = mintAmount - half;
        // First
        riseToken.transfer(address(riseToken), half);
        riseToken.burnd(minter, 0);
        // Second
        riseToken.transfer(address(riseToken), left);
        riseToken.burnd(minter, 0);

        // Check minter balance
        assertEq(riseToken.balanceOf(minter), 0, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
        assertEq(riseToken.price(), price, "invalid price");
        uint256 currentLR = riseToken.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is decreased
        assertEq(riseToken.totalSupply(), ts - mintAmount, "invalid ts");
    }

    /// @notice Make sure burn twice in a row doesn't change the price
    function testBurnTwiceViaCollateral() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(data.collateral),
            data.collateralSlot,
            data.factory.feeRecipient(),
            0
        );

        // Mint
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;
        uint256 amountIn = getAmountIn(
            riseToken,
            mintAmount,
            address(data.collateral)
        );
        setBalance(
            address(data.collateral),
            data.collateralSlot,
            minter,
            amountIn
        );
        data.collateral.transfer(address(riseToken), amountIn);
        riseToken.mintc(mintAmount, minter, minter);

        // Make sure these values does not change after burn
        uint256 cps = riseToken.collateralPerShare();
        uint256 dps = riseToken.debtPerShare();
        uint256 price = riseToken.price();
        uint256 lr  = riseToken.leverageRatio();

        // Make sure these values is decreased after burn
        uint256 ts = riseToken.totalSupply();

        // Burn
        uint256 half = uint256(0.5 ether).mulWadDown(mintAmount);
        uint256 left = mintAmount - half;
        // First
        riseToken.transfer(address(riseToken), half);
        riseToken.burnc(minter, 0);
        // Second
        riseToken.transfer(address(riseToken), left);
        riseToken.burnc(minter, 0);

        // Check minter balance
        assertEq(riseToken.balanceOf(minter), 0, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
        assertEq(riseToken.price(), price, "invalid price");
        uint256 currentLR = riseToken.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is decreased
        assertEq(riseToken.totalSupply(), ts - mintAmount, "invalid ts");
    }

}
