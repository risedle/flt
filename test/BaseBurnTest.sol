// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { IFLT } from "../src/interfaces/IFLT.sol";

import { BaseTest } from "./BaseTest.sol";

abstract contract BaseBurnTest is BaseTest {

    using FixedPointMathLib for uint256;

    /// @notice Make sure it revert when token is not initialized
    function testBurnRevertIfNotInitializedViaDebt() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        IFLT flt = deploy(data);

        // MintFromDebt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.Uninitialized.selector
            )
        );
        flt.burnd(address(this), 0);
    }

    /// @notice Make sure it revert when token is not initialized
    function testBurnRevertIfNotInitializedViaCollateral() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        IFLT flt = deploy(data);

        // MintFromDebt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.Uninitialized.selector
            )
        );
        flt.burnc(address(this), 0);
    }

    /// @notice Make sure it revert when burn amount is zero
    function testBurnRevertIfBurnAmountIsZeroViaDebt() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);

        // Burn to debt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountInTooLow.selector
            )
        );
        flt.burnd(address(this), 0);
    }

    /// @notice Make sure it revert when burn amount is zero
    function testBurnRevertIfBurnAmountIsZeroViaCollateral() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);

        // Burn to collateral; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountInTooLow.selector
            )
        );
        flt.burnc(address(this), 0);
    }

    /// @notice Make sure it revert if amount out less than min amount out
    function testBurnRevertIfAmountOutLessThanMinAmountOutViaDebt() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);

        // Mint first
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;
        uint256 amountIn = getAmountIn(
            address(flt),
            mintAmount,
            address(flt.debt())
        );
        setBalance(address(flt.debt()), data.debtSlot, minter, amountIn);
        flt.debt().transfer(address(flt), amountIn);
        flt.mintd(mintAmount, minter, minter);

        // Transfer token to burn
        ERC20(address(flt)).transfer(address(flt), mintAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountOutTooLow.selector
            )
        );
        flt.burnd(address(this), 1e18 ether);
    }

    /// @notice Make sure it revert if amount out less than min amount out
    function testBurnRevertIfAmountOutLessThanMinAmountOutViaCollateral() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);

        // Mint first
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;
        uint256 amountIn = getAmountIn(
            address(flt),
            mintAmount,
            address(flt.collateral())
        );
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            minter,
            amountIn
        );
        ERC20(address(flt.collateral())).transfer(address(flt), amountIn);
        flt.mintc(mintAmount, minter, minter);

        // Transfer to burn
        ERC20(address(flt)).transfer(address(flt), mintAmount);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountOutTooLow.selector
            )
        );
        flt.burnc(address(this), 1e18 ether);
    }

    /// @notice Make sure burn doesn't change the price
    function testBurnWithLeverageRatioViaDebt(uint256 _lr) internal {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, _lr);

        // Reset fee recipient balance to zero
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            flt.factory().feeRecipient(),
            0
        );

        // Mint
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;
        uint256 amountIn = getAmountIn(
            address(flt),
            mintAmount,
            address(flt.debt())
        );
        setBalance(address(flt.debt()), data.debtSlot, minter, amountIn);
        flt.debt().transfer(address(flt), amountIn);
        flt.mintd(mintAmount, minter, minter);

        // Make sure these values does not change after burn
        uint256 cps = flt.collateralPerShare();
        uint256 dps = flt.debtPerShare();
        uint256 price = flt.price();
        uint256 lr  = flt.leverageRatio();
        uint256 fb = flt.debt().balanceOf(flt.factory().feeRecipient());

        // Make sure these values is decreased after burn
        uint256 ts = ERC20(address(flt)).totalSupply();

        // Burn
        ERC20(address(flt)).transfer(address(flt), mintAmount);
        flt.burnd(minter, 0);

        // Check minter balance
        assertEq(ERC20(address(flt)).balanceOf(minter), 0, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(flt.collateralPerShare(), cps, "invalid cps");
        assertEq(flt.debtPerShare(), dps, "invalid dps");
        assertEq(flt.price(), price, "invalid price");
        uint256 currentLR = flt.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is decreased
        assertEq(ERC20(address(flt)).totalSupply(), ts - mintAmount, "invalid ts");

        // Make sure fee recipient receive 0.1%x2 of amountIn
        assertGt(
            flt.debt().balanceOf(flt.factory().feeRecipient()),
            fb,
            "invalid fee recipient"
        );
        assertEq(
            ERC20(address(flt.collateral())).balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );

        // Make sure there are no tokens inside contract
        assertEq(
            flt.debt().balanceOf(address(flt)),
            0,
            "invalid debt contract balance"
        );
        assertEq(
            ERC20(address(flt.collateral())).balanceOf(address(flt)),
            0,
            "invalid collateral contract balance"
        );
    }

    /// @notice Make sure burn doesn't change the price
    function testBurnWithLeverageRatioViaCollateral(uint256 _lr) internal {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, _lr);

        // Reset fee recipient balance to zero
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            flt.factory().feeRecipient(),
            0
        );

        // Mint
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;
        uint256 amountIn = getAmountIn(
            address(flt),
            mintAmount,
            address(flt.collateral())
        );
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            minter,
            amountIn
        );
        ERC20(address(flt.collateral())).transfer(address(flt), amountIn);
        flt.mintc(mintAmount, minter, minter);

        // Make sure these values does not change after burn
        uint256 cps = flt.collateralPerShare();
        uint256 dps = flt.debtPerShare();
        uint256 price = flt.price();
        uint256 lr  = flt.leverageRatio();
        uint256 fb = flt.debt().balanceOf(flt.factory().feeRecipient());

        // Make sure these values is decreased after burn
        uint256 ts = ERC20(address(flt)).totalSupply();

        // Burn
        ERC20(address(flt)).transfer(address(flt), mintAmount);
        flt.burnc(minter, 0);

        // Check minter balance
        assertEq(ERC20(address(flt)).balanceOf(minter), 0, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(flt.collateralPerShare(), cps, "invalid cps");
        assertEq(flt.debtPerShare(), dps, "invalid dps");
        assertEq(flt.price(), price, "invalid price");
        uint256 currentLR = flt.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is decreased
        assertEq(ERC20(address(flt)).totalSupply(), ts - mintAmount, "invalid ts");

        // Make sure fee recipient receive 0.1%x2 of amountIn
        assertGt(
            ERC20(address(flt.collateral())).balanceOf(flt.factory().feeRecipient()),
            fb,
            "invalid fee recipient"
        );
        assertEq(
            flt.debt().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );

        // Make sure there are no tokens inside contract
        assertEq(
            flt.debt().balanceOf(address(flt)),
            0,
            "invalid debt contract balance"
        );
        assertEq(
            ERC20(address(flt.collateral())).balanceOf(address(flt)),
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
        IFLT flt = deployAndInitialize(data, 2 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            flt.factory().feeRecipient(),
            0
        );

        // Mint
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;
        uint256 amountIn = getAmountIn(
            address(flt),
            mintAmount,
            address(flt.debt())
        );
        setBalance(address(flt.debt()), data.debtSlot, minter, amountIn);
        flt.debt().transfer(address(flt), amountIn);
        flt.mintd(mintAmount, minter, minter);

        // Make sure these values does not change after burn
        uint256 cps = flt.collateralPerShare();
        uint256 dps = flt.debtPerShare();
        uint256 price = flt.price();
        uint256 lr  = flt.leverageRatio();

        // Make sure these values is decreased after burn
        uint256 ts = ERC20(address(flt)).totalSupply();

        // Burn
        uint256 half = uint256(0.5 ether).mulWadDown(mintAmount);
        uint256 left = mintAmount - half;
        // First
        ERC20(address(flt)).transfer(address(flt), half);
        flt.burnd(minter, 0);
        // Second
        ERC20(address(flt)).transfer(address(flt), left);
        flt.burnd(minter, 0);

        // Check minter balance
        assertEq(ERC20(address(flt)).balanceOf(minter), 0, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(flt.collateralPerShare(), cps, "invalid cps");
        assertGt(flt.debtPerShare(), dps-2, "dps too low");
        assertLt(flt.debtPerShare(), dps+2, "dps too low");
        assertGt(flt.price(), price-2, "price too low");
        assertLt(flt.price(), price+2, "price too high");
        uint256 currentLR = flt.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is decreased
        assertEq(ERC20(address(flt)).totalSupply(), ts - mintAmount, "invalid ts");
    }

    /// @notice Make sure burn twice in a row doesn't change the price
    function testBurnTwiceViaCollateral() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            flt.factory().feeRecipient(),
            0
        );

        // Mint
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;
        uint256 amountIn = getAmountIn(
            address(flt),
            mintAmount,
            address(flt.collateral())
        );
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            minter,
            amountIn
        );
        ERC20(address(flt.collateral())).transfer(address(flt), amountIn);
        flt.mintc(mintAmount, minter, minter);

        // Make sure these values does not change after burn
        uint256 cps = flt.collateralPerShare();
        uint256 dps = flt.debtPerShare();
        uint256 price = flt.price();
        uint256 lr  = flt.leverageRatio();

        // Make sure these values is decreased after burn
        uint256 ts = ERC20(address(flt)).totalSupply();

        // Burn
        uint256 half = uint256(0.5 ether).mulWadDown(mintAmount);
        uint256 left = mintAmount - half;
        // First
        ERC20(address(flt)).transfer(address(flt), half);
        flt.burnc(minter, 0);
        // Second
        ERC20(address(flt)).transfer(address(flt), left);
        flt.burnc(minter, 0);

        // Check minter balance
        assertEq(ERC20(address(flt)).balanceOf(minter), 0, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(flt.collateralPerShare(), cps, "invalid cps");
        assertGt(flt.debtPerShare(), dps-2, "dps too low");
        assertLt(flt.debtPerShare(), dps+2, "dps too low");
        assertGt(flt.price(), price-2, "price too low");
        assertLt(flt.price(), price+2, "price too high");
        uint256 currentLR = flt.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is decreased
        assertEq(ERC20(address(flt)).totalSupply(), ts - mintAmount, "invalid ts");
    }

}
