// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { RiseToken } from "../src/RiseToken.sol";
import { IRiseToken } from "../src/interfaces/IRiseToken.sol";

import { BaseTest } from "./BaseTest.sol";

abstract contract BaseBurnTest is BaseTest {

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
                IRiseToken.BurnAmountTooLow.selector
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
                IRiseToken.BurnAmountTooLow.selector
            )
        );
        riseToken.burnc(address(this), 0);
    }

    /// @notice Make sure it revert if amount out less than min amount out
//    function testBurnRevertIfAmountOutLessThanMinAmountOutViaDebt() public {
//        // Get data
//        Data memory data = getData();
//        RiseToken riseToken = deployAndInitialize(data, 2 ether);
//
//        // Mint first
//        address minter = vm.addr(1);
//        startHoax(minter);
//        uint256 mintAmount = 5 ether;
//        uint256 amountIn = getAmountIn(
//            riseToken,
//            mintAmount,
//            address(data.debt)
//        );
//        setBalance(address(data.debt), data.debtSlot, minter, amountIn);
//        data.debt.transfer(address(riseToken), amountIn);
//        riseToken.mintd(mintAmount, minter);
//
//        vm.expectRevert(
//            abi.encodeWithSelector(
//                IRiseToken.AmountOutTooLow.selector
//            )
//        );
//        riseToken.burnd(mintAmount, address(this), 1e18 ether);
//    }

    /// @notice Make sure it revert if amount out less than min amount out
//    function testBurnRevertIfAmountOutLessThanMinAmountOutViaCollateral() public {
//        // Get data
//        Data memory data = getData();
//        RiseToken riseToken = deployAndInitialize(data, 2 ether);
//
//        // Mint first
//        address minter = vm.addr(1);
//        startHoax(minter);
//        uint256 mintAmount = 5 ether;
//        uint256 amountIn = getAmountIn(
//            riseToken,
//            mintAmount,
//            address(data.collateral)
//        );
//        setBalance(
//            address(data.collateral),
//            data.collateralSlot,
//            minter,
//            amountIn
//        );
//        data.collateral.transfer(address(riseToken), amountIn);
//        riseToken.mintc(mintAmount, minter);
//
//        vm.expectRevert(
//            abi.encodeWithSelector(
//                IRiseToken.AmountOutTooLow.selector
//            )
//        );
//        riseToken.burnc(mintAmount, address(this), 1e18 ether);
//    }


//    /// @notice Make sure burn doesn't change the price
//    function testBurnWithLeverageRatio2xViaDebt() public {
//        // Get data
//        Data memory data = getData();
//        RiseToken riseToken = deployAndInitialize(data, 2 ether);
//
//        // Reset fee recipient balance to zero
//        setBalance(
//            address(data.debt),
//            data.debtSlot,
//            data.factory.feeRecipient(),
//            0
//        );
//
//        // Make sure these values does not change after mint
//        uint256 cps = riseToken.collateralPerShare();
//        uint256 dps = riseToken.debtPerShare();
//        uint256 price = riseToken.price();
//        uint256 lr  = riseToken.leverageRatio();
//
//        // Make sure these values is increased after mint
//        uint256 ts = riseToken.totalSupply();
//
//        // Mint
//        address minter = vm.addr(1);
//        startHoax(minter);
//        uint256 mintAmount = 5 ether;
//        uint256 amountIn = getAmountIn(
//            riseToken,
//            mintAmount,
//            address(data.debt)
//        );
//        setBalance(address(data.debt), data.debtSlot, minter, amountIn);
//        data.debt.transfer(address(riseToken), amountIn);
//        riseToken.mintd(mintAmount, minter);
//        // riseToken.burnd(mintAmount, minter, amountOut);
//
//        // Check minter balance
//        assertEq(riseToken.balanceOf(minter), mintAmount, "invalid minter b");
//
//        // Make sure these values doesn't changes
//        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
//        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
//        assertEq(riseToken.price(), price, "invalid price");
//        uint256 currentLR = riseToken.leverageRatio();
//        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
//        assertLt(currentLR, lr + 0.0001 ether, "lr too high");
//
//        // Make sure total supply is increased
//        assertEq(riseToken.totalSupply(), ts + mintAmount, "invalid ts");
//
//        // Make sure fee recipient receive 0.1% of amountIn
//        assertGt(
//            data.debt.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//        assertEq(
//            data.collateral.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//    }

//    /// @notice Make sure mint doesn't change the price
//    function testMintWithLeverageRatio2xViaCollateral() public {
//        // Get data
//        Data memory data = getData();
//        RiseToken riseToken = deployAndInitialize(data, 2 ether);
//
//        // Reset fee recipient balance to zero
//        setBalance(
//            address(data.collateral),
//            data.collateralSlot,
//            data.factory.feeRecipient(),
//            0
//        );
//
//        // Make sure these values does not change after mint
//        uint256 cps = riseToken.collateralPerShare();
//        uint256 dps = riseToken.debtPerShare();
//        uint256 price = riseToken.price();
//        uint256 lr  = riseToken.leverageRatio();
//
//        // Make sure these values is increased after mint
//        uint256 ts = riseToken.totalSupply();
//
//        // Mint
//        address minter = vm.addr(1);
//        startHoax(minter);
//        uint256 mintAmount = 5 ether;
//        uint256 amountIn = getAmountIn(
//            riseToken,
//            mintAmount,
//            address(data.collateral)
//        );
//        setBalance(
//            address(data.collateral),
//            data.collateralSlot,
//            minter,
//            amountIn
//        );
//        data.collateral.transfer(address(riseToken), amountIn);
//        riseToken.mintc(mintAmount, minter);
//
//        // Check minter balance
//        assertEq(riseToken.balanceOf(minter), mintAmount, "invalid minter b");
//
//        // Make sure these values doesn't changes
//        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
//        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
//        assertEq(riseToken.price(), price, "invalid price");
//        uint256 currentLR = riseToken.leverageRatio();
//        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
//        assertLt(currentLR, lr + 0.0001 ether, "lr too high");
//
//        // Make sure total supply is increased
//        assertEq(riseToken.totalSupply(), ts + mintAmount, "invalid ts");
//
//        // Make sure fee recipient receive 0.1% of amountIn
//        assertGt(
//            data.collateral.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//        assertEq(
//            data.debt.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//    }
//
//    /// @notice Make sure mint doesn't change the price
//    function testMintWithLeverageRatioLessThan2xViaDebt() public {
//        // Get data
//        Data memory data = getData();
//        RiseToken riseToken = deployAndInitialize(data, 1.6 ether);
//
//        // Reset fee recipient balance to zero
//        setBalance(
//            address(data.debt),
//            data.debtSlot,
//            data.factory.feeRecipient(),
//            0
//        );
//
//        // Make sure these values does not change after mint
//        uint256 cps = riseToken.collateralPerShare();
//        uint256 dps = riseToken.debtPerShare();
//        uint256 price = riseToken.price();
//        uint256 lr  = riseToken.leverageRatio();
//
//        // Make sure these values is increased after mint
//        uint256 ts = riseToken.totalSupply();
//
//        // MintFromDebt
//        address minter = vm.addr(1);
//        startHoax(minter);
//        uint256 mintAmount = 5 ether;
//        uint256 amountIn = getAmountIn(
//            riseToken,
//            mintAmount,
//            address(data.debt)
//        );
//        setBalance(address(data.debt), data.debtSlot, minter, amountIn);
//        data.debt.transfer(address(riseToken), amountIn);
//        riseToken.mintd(mintAmount, minter);
//
//        // Check minter balance
//        assertEq(riseToken.balanceOf(minter), mintAmount, "invalid minter b");
//
//        // Make sure these values doesn't changes
//        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
//        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
//        assertEq(riseToken.price(), price, "invalid price");
//        uint256 currentLR = riseToken.leverageRatio();
//        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
//        assertLt(currentLR, lr + 0.0001 ether, "lr too high");
//
//        // Make sure total supply is increased
//        assertEq(riseToken.totalSupply(), ts + mintAmount, "invalid ts");
//
//        // Make sure fee recipient receive 0.1% of amountIn
//        assertGt(
//            data.debt.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//        assertEq(
//            data.collateral.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//    }
//
//    /// @notice Make sure mint doesn't change the price
//    function testMintWithLeverageRatioLessThan2xViaCollateral() public {
//        // Get data
//        Data memory data = getData();
//        RiseToken riseToken = deployAndInitialize(data, 1.6 ether);
//
//        // Reset fee recipient balance to zero
//        setBalance(
//            address(data.collateral),
//            data.collateralSlot,
//            data.factory.feeRecipient(),
//            0
//        );
//
//        // Make sure these values does not change after mint
//        uint256 cps = riseToken.collateralPerShare();
//        uint256 dps = riseToken.debtPerShare();
//        uint256 price = riseToken.price();
//        uint256 lr  = riseToken.leverageRatio();
//
//        // Make sure these values is increased after mint
//        uint256 ts = riseToken.totalSupply();
//
//        // MintFromDebt
//        address minter = vm.addr(1);
//        startHoax(minter);
//        uint256 mintAmount = 5 ether;
//        uint256 amountIn = getAmountIn(
//            riseToken,
//            mintAmount,
//            address(data.collateral)
//        );
//        setBalance(
//            address(data.collateral),
//            data.collateralSlot,
//            minter,
//            amountIn
//        );
//        data.collateral.transfer(address(riseToken), amountIn);
//        riseToken.mintc(mintAmount, minter);
//
//        // Check minter balance
//        assertEq(riseToken.balanceOf(minter), mintAmount, "invalid minter b");
//
//        // Make sure these values doesn't changes
//        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
//        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
//        assertEq(riseToken.price(), price, "invalid price");
//        uint256 currentLR = riseToken.leverageRatio();
//        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
//        assertLt(currentLR, lr + 0.0001 ether, "lr too high");
//
//        // Make sure total supply is increased
//        assertEq(riseToken.totalSupply(), ts + mintAmount, "invalid ts");
//
//        // Make sure fee recipient receive 0.1% of amountIn
//        assertGt(
//            data.collateral.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//        assertEq(
//            data.debt.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//    }
//
//    /// @notice Make sure mint doesn't change the price
//    function testMintWithLeverageRatioGreaterThan2xViaDebt() public {
//        // Get data
//        Data memory data = getData();
//        RiseToken riseToken = deployAndInitialize(data, 2.5 ether);
//
//        // Reset fee recipient balance to zero
//        setBalance(
//            address(data.debt),
//            data.debtSlot,
//            data.factory.feeRecipient(),
//            0
//        );
//
//        // Make sure these values does not change after mint
//        uint256 cps = riseToken.collateralPerShare();
//        uint256 dps = riseToken.debtPerShare();
//        uint256 price = riseToken.price();
//        uint256 lr  = riseToken.leverageRatio();
//
//        // Make sure these values is increased after mint
//        uint256 ts = riseToken.totalSupply();
//
//        // MintFromDebt
//        address minter = vm.addr(1);
//        startHoax(minter);
//        uint256 mintAmount = 5 ether;
//        uint256 amountIn = getAmountIn(
//            riseToken,
//            mintAmount,
//            address(data.debt)
//        );
//        setBalance(address(data.debt), data.debtSlot, minter, amountIn);
//        data.debt.transfer(address(riseToken), amountIn);
//        riseToken.mintd(mintAmount, minter);
//
//        // Check minter balance
//        assertEq(riseToken.balanceOf(minter), mintAmount, "invalid minter b");
//
//        // Make sure these values doesn't changes
//        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
//        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
//        assertEq(riseToken.price(), price, "invalid price");
//        uint256 currentLR = riseToken.leverageRatio();
//        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
//        assertLt(currentLR, lr + 0.0001 ether, "lr too high");
//
//        // Make sure total supply is increased
//        assertEq(riseToken.totalSupply(), ts + mintAmount, "invalid ts");
//
//        // Make sure fee recipient receive 0.1% of amountIn
//        assertGt(
//            data.debt.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//        assertEq(
//            data.collateral.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//    }
//
//    /// @notice Make sure mint doesn't change the price
//    function testMintWithLeverageRatioGreaterThan2xViaCollateral() public {
//        // Get data
//        Data memory data = getData();
//        RiseToken riseToken = deployAndInitialize(data, 2.5 ether);
//
//        // Reset fee recipient balance to zero
//        setBalance(
//            address(data.collateral),
//            data.collateralSlot,
//            data.factory.feeRecipient(),
//            0
//        );
//
//        // Make sure these values does not change after mint
//        uint256 cps = riseToken.collateralPerShare();
//        uint256 dps = riseToken.debtPerShare();
//        uint256 price = riseToken.price();
//        uint256 lr  = riseToken.leverageRatio();
//
//        // Make sure these values is increased after mint
//        uint256 ts = riseToken.totalSupply();
//
//        // Mint
//        address minter = vm.addr(1);
//        startHoax(minter);
//        uint256 mintAmount = 5 ether;
//        uint256 amountIn = getAmountIn(
//            riseToken,
//            mintAmount,
//            address(data.collateral)
//        );
//        setBalance(
//            address(data.collateral),
//            data.collateralSlot,
//            minter,
//            amountIn
//        );
//        data.collateral.transfer(address(riseToken), amountIn);
//        riseToken.mintc(mintAmount, minter);
//
//        // Check minter balance
//        assertEq(riseToken.balanceOf(minter), mintAmount, "invalid minter b");
//
//        // Make sure these values doesn't changes
//        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
//        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
//        assertEq(riseToken.price(), price, "invalid price");
//        uint256 currentLR = riseToken.leverageRatio();
//        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
//        assertLt(currentLR, lr + 0.0001 ether, "lr too high");
//
//        // Make sure total supply is increased
//        assertEq(riseToken.totalSupply(), ts + mintAmount, "invalid ts");
//
//        // Make sure fee recipient receive 0.1% of amountIn
//        assertGt(
//            data.collateral.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//        assertEq(
//            data.debt.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//    }
//
//    /// @notice Make sure mint twice doesn't change the price
//    function testMintTwiceViaDebt() public {
//        // Get data
//        Data memory data = getData();
//        RiseToken riseToken = deployAndInitialize(data, 2.5 ether);
//
//        // Reset fee recipient balance to zero
//        setBalance(
//            address(data.debt),
//            data.debtSlot,
//            data.factory.feeRecipient(),
//            0
//        );
//
//        // Make sure these values does not change after mint
//        uint256 cps = riseToken.collateralPerShare();
//        uint256 dps = riseToken.debtPerShare();
//        uint256 price = riseToken.price();
//        uint256 lr  = riseToken.leverageRatio();
//
//        // Make sure these values is increased after mint
//        uint256 ts = riseToken.totalSupply();
//
//        // MintFromDebt
//        address minter = vm.addr(1);
//        startHoax(minter);
//        uint256 mintAmount = 5 ether;
//
//        // First
//        uint256 amountIn = getAmountIn(
//            riseToken,
//            mintAmount,
//            address(data.debt)
//        );
//        setBalance(address(data.debt), data.debtSlot, minter, amountIn);
//        data.debt.transfer(address(riseToken), amountIn);
//        riseToken.mintd(mintAmount, minter);
//
//        // Second
//        amountIn = getAmountIn(
//            riseToken,
//            mintAmount,
//            address(data.debt)
//        );
//        setBalance(address(data.debt), data.debtSlot, minter, amountIn);
//        data.debt.transfer(address(riseToken), amountIn);
//        riseToken.mintd(mintAmount, minter);
//
//        // Check minter balance
//        assertEq(riseToken.balanceOf(minter), 2*mintAmount, "invalid minter b");
//
//        // Make sure these values doesn't changes
//        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
//        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
//        assertEq(riseToken.price(), price, "invalid price");
//        uint256 currentLR = riseToken.leverageRatio();
//        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
//        assertLt(currentLR, lr + 0.0001 ether, "lr too high");
//
//        // Make sure total supply is increased
//        assertEq(riseToken.totalSupply(), ts + (2*mintAmount), "invalid ts");
//        // Make sure fee recipient receive 0.1% of amountIn
//        assertGt(
//            data.debt.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//        assertEq(
//            data.collateral.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//    }
//
//    /// @notice Make sure mint twice doesn't change the price
//    function testMintTwiceViaCollateral() public {
//        // Get data
//        Data memory data = getData();
//        RiseToken riseToken = deployAndInitialize(data, 2.5 ether);
//
//        // Reset fee recipient balance to zero
//        setBalance(
//            address(data.collateral),
//            data.collateralSlot,
//            data.factory.feeRecipient(),
//            0
//        );
//
//        // Make sure these values does not change after mint
//        uint256 cps = riseToken.collateralPerShare();
//        uint256 dps = riseToken.debtPerShare();
//        uint256 price = riseToken.price();
//        uint256 lr  = riseToken.leverageRatio();
//
//        // Make sure these values is increased after mint
//        uint256 ts = riseToken.totalSupply();
//
//        // MintFromDebt
//        address minter = vm.addr(1);
//        startHoax(minter);
//        uint256 mintAmount = 5 ether;
//
//        // First
//        uint256 amountIn = getAmountIn(
//            riseToken,
//            mintAmount,
//            address(data.collateral)
//        );
//        setBalance(
//            address(data.collateral),
//            data.collateralSlot,
//            minter,
//            amountIn
//        );
//        data.collateral.transfer(address(riseToken), amountIn);
//        riseToken.mintc(mintAmount, minter);
//
//        // Second
//        amountIn = getAmountIn(
//            riseToken,
//            mintAmount,
//            address(data.collateral)
//        );
//        setBalance(
//            address(data.collateral),
//            data.collateralSlot,
//            minter,
//            amountIn
//        );
//        data.collateral.transfer(address(riseToken), amountIn);
//        riseToken.mintc(mintAmount, minter);
//
//        // Check minter balance
//        assertEq(riseToken.balanceOf(minter), 2*mintAmount, "invalid minter b");
//
//        // Make sure these values doesn't changes
//        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
//        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
//        assertEq(riseToken.price(), price, "invalid price");
//        uint256 currentLR = riseToken.leverageRatio();
//        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
//        assertLt(currentLR, lr + 0.0001 ether, "lr too high");
//
//        // Make sure total supply is increased
//        assertEq(riseToken.totalSupply(), ts + (2*mintAmount), "invalid ts");
//        // Make sure fee recipient receive 0.1% of amountIn
//        assertGt(
//            data.collateral.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//        assertEq(
//            data.debt.balanceOf(data.factory.feeRecipient()),
//            0,
//            "invalid fee recipient"
//        );
//    }
//
//    /// @notice Make sure mint are refunded
//    function testMintRefundViaDebt() public {
//        // Get data
//        Data memory data = getData();
//        RiseToken riseToken = deployAndInitialize(data, 2 ether);
//
//        // MintFromDebt
//        address minter = vm.addr(1);
//        startHoax(minter);
//        uint256 mintAmount = 5 ether;
//
//        // First
//        uint256 amountIn = getAmountIn(
//            riseToken,
//            mintAmount,
//            address(data.debt)
//        );
//        setBalance(address(data.debt), data.debtSlot, minter, 2*amountIn);
//        data.debt.transfer(address(riseToken), 2*amountIn);
//        riseToken.mintd(mintAmount, minter);
//
//        // Check minter balance
//        assertEq(data.debt.balanceOf(minter), amountIn, "invalid balance");
//    }
//
//    /// @notice Make sure mint are refunded
//    function testMintRefundViaCollateral() public {
//        // Get data
//        Data memory data = getData();
//        RiseToken riseToken = deployAndInitialize(data, 2 ether);
//
//        // MintFromDebt
//        address minter = vm.addr(1);
//        startHoax(minter);
//        uint256 mintAmount = 5 ether;
//
//        // First
//        uint256 amountIn = getAmountIn(
//            riseToken,
//            mintAmount,
//            address(data.collateral)
//        );
//        setBalance(
//            address(data.collateral),
//            data.collateralSlot,
//            minter,
//            2*amountIn
//        );
//        data.collateral.transfer(address(riseToken), 2*amountIn);
//        riseToken.mintc(mintAmount, minter);
//
//        // Check minter balance
//        assertEq(data.collateral.balanceOf(minter), amountIn, "invalid balance");
//    }

}
