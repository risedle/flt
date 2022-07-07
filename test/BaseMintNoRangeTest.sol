// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { IFLT } from "../src/interfaces/IFLT.sol";
import { FLTSinglePairNoRange } from "../src/FLTSinglePairNoRange.sol";

import { BaseTest } from "./BaseTest.sol";

abstract contract BaseMintNoRangeTest is BaseTest {

    /// @notice Make sure pool is seeded
    function _seedPool(IFLT flt) internal {
        // Get data
        Data memory data = getData();

        // Add supply to Risedle Pool
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            data.debtSupplyAmount
        );
        flt.debt().approve(address(flt.fDebt()), data.debtSupplyAmount);
        flt.fDebt().mint(data.debtSupplyAmount);
    }

    /// @notice Make sure it revert when token is not initialized
    function testMintRevertIfNotInitializedViaDebt() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        IFLT flt = deploy(data);

        // Seed pool
        _seedPool(flt);

        // MintFromDebt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.Uninitialized.selector
            )
        );
        flt.mintd(1 ether, address(this), address(this));
    }

    /// @notice Make sure it revert when token is not initialized
    function testMintRevertIfNotInitializedViaCollateral() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        IFLT flt = deploy(data);

        // Seed pool
        _seedPool(flt);

        // MintFromDebt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.Uninitialized.selector
            )
        );
        flt.mintc(1 ether, address(this), address(this));
    }

    /// @notice Make sure it revert when mint amount is more than max supply
    function testMintRevertIfMoreThanMaxSupplyViaDebt() public {
        // Get data
        Data memory data = getData();
        IFLT _flt = deployAndInitialize(data, 2 ether);
        FLTSinglePairNoRange flt = FLTSinglePairNoRange(address(_flt));

        // Set max supply to current + 1 ether
        flt.setMaxSupply(flt.totalSupply() + 1 ether);

        // Mint 2 ether; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountOutTooHigh.selector
            )
        );
        flt.mintd(2 ether, address(this), address(this));
    }

    /// @notice Make sure it revert when mint amount is more than max supply
    function testMintRevertIfMoreThanMaxSupplyViaCollateral() public {
        // Get data
        Data memory data = getData();
        IFLT _flt = deployAndInitialize(data, 2 ether);
        FLTSinglePairNoRange flt = FLTSinglePairNoRange(address(_flt));

        // Set max supply to current + 1 ether
        flt.setMaxSupply(flt.totalSupply() + 1 ether);

        // Mint 2 ether; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountOutTooHigh.selector
            )
        );
        flt.mintc(2 ether, address(this), address(this));
    }

    /// @notice Make sure it revert when mint amount is zero
    function testMintRevertIfMintAmountIsZeroViaDebt() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);

        // MintFromDebt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountOutTooLow.selector
            )
        );
        flt.mintd(0, address(this), address(this));
    }

    /// @notice Make sure it revert when mint amount is zero
    function testMintRevertIfMintAmountIsZeroViaCollateral() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);

        // MintFromDebt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountOutTooLow.selector
            )
        );
        flt.mintc(0, address(this), address(this));
    }

    /// @notice Make sure it revert when required amount is not send
    function testMintRevertIfRequiredAmountNotReceivedViaDebt() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);

        // MintFromDebt; this should revert
        uint256 mintAmount = 5 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountInTooLow.selector
            )
        );
        flt.mintd(mintAmount, address(this), address(this));
    }

    /// @notice Make sure it revert when required amount is not send
    function testMintRevertIfRequiredAmountNotReceivedViaCollateral() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);

        // MintFromDebt; this should revert
        uint256 mintAmount = 5 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountInTooLow.selector
            )
        );
        flt.mintc(mintAmount, address(this), address(this));
    }

    /// @notice Make sure mint doesn't change the price
    function testMintWithLeverageRatio2xViaDebt() public {
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
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            flt.factory().feeRecipient(),
            0
        );

        // Make sure these values does not change after mint
        uint256 cps = flt.collateralPerShare();
        uint256 dps = flt.debtPerShare();
        uint256 price = flt.price();
        uint256 lr  = flt.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = ERC20(address(flt)).totalSupply();

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

        // Check minter balance
        assertEq(
            ERC20(address(flt)).balanceOf(minter),
            mintAmount,
            "invalid minter b"
        );

        // Make sure these values doesn't changes
        assertEq(flt.collateralPerShare(), cps, "invalid cps");
        assertEq(flt.debtPerShare(), dps, "invalid dps");
        assertEq(flt.price(), price, "invalid price");
        uint256 currentLR = flt.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(
            ERC20(address(flt)).totalSupply(),
            ts + mintAmount,
            "invalid ts"
        );

        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            flt.debt().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            flt.collateral().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint doesn't change the price
    function testMintWithLeverageRatio2xViaCollateral() public {
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
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            flt.factory().feeRecipient(),
            0
        );

        // Make sure these values does not change after mint
        uint256 cps = flt.collateralPerShare();
        uint256 dps = flt.debtPerShare();
        uint256 price = flt.price();
        uint256 lr  = flt.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = ERC20(address(flt)).totalSupply();

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
        flt.collateral().transfer(address(flt), amountIn);
        flt.mintc(mintAmount, minter, minter);

        // Check minter balance
        assertEq(
            ERC20(address(flt)).balanceOf(minter),
            mintAmount,
            "invalid minter b"
        );

        // Make sure these values doesn't changes
        assertEq(flt.collateralPerShare(), cps, "invalid cps");
        assertEq(flt.debtPerShare(), dps, "invalid dps");
        assertEq(flt.price(), price, "invalid price");
        uint256 currentLR = flt.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(
            ERC20(address(flt)).totalSupply(),
            ts + mintAmount,
            "invalid ts"
        );

        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            flt.collateral().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            flt.debt().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint doesn't change the price
    function testMintWithLeverageRatioLessThan2xViaDebt() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 1.6 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            flt.factory().feeRecipient(),
            0
        );
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            flt.factory().feeRecipient(),
            0
        );

        // Make sure these values does not change after mint
        uint256 cps = flt.collateralPerShare();
        uint256 dps = flt.debtPerShare();
        uint256 price = flt.price();
        uint256 lr  = flt.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = ERC20(address(flt)).totalSupply();

        // MintFromDebt
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

        // Check minter balance
        assertEq(
            ERC20(address(flt)).balanceOf(minter),
            mintAmount,
            "invalid minter b"
        );

        // Make sure these values doesn't changes
        assertEq(flt.collateralPerShare(), cps, "invalid cps");
        assertEq(flt.debtPerShare(), dps, "invalid dps");
        assertEq(flt.price(), price, "invalid price");
        uint256 currentLR = flt.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(
            ERC20(address(flt)).totalSupply(),
            ts + mintAmount,
            "invalid ts"
        );

        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            flt.debt().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            flt.collateral().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint doesn't change the price
    function testMintWithLeverageRatioLessThan2xViaCollateral() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 1.6 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            flt.factory().feeRecipient(),
            0
        );
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            flt.factory().feeRecipient(),
            0
        );

        // Make sure these values does not change after mint
        uint256 cps = flt.collateralPerShare();
        uint256 dps = flt.debtPerShare();
        uint256 price = flt.price();
        uint256 lr  = flt.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = ERC20(address(flt)).totalSupply();

        // MintFromDebt
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
        flt.collateral().transfer(address(flt), amountIn);
        flt.mintc(mintAmount, minter, minter);

        // Check minter balance
        assertEq(
            ERC20(address(flt)).balanceOf(minter),
            mintAmount,
            "invalid minter b"
        );

        // Make sure these values doesn't changes
        assertEq(flt.collateralPerShare(), cps, "invalid cps");
        assertEq(flt.debtPerShare(), dps, "invalid dps");
        assertEq(flt.price(), price, "invalid price");
        uint256 currentLR = flt.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(
            ERC20(address(flt)).totalSupply(),
            ts + mintAmount,
            "invalid ts"
        );

        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            flt.collateral().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            flt.debt().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint doesn't change the price
    function testMintWithLeverageRatioGreaterThan2xViaDebt() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2.5 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            flt.factory().feeRecipient(),
            0
        );
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            flt.factory().feeRecipient(),
            0
        );

        // Make sure these values does not change after mint
        uint256 cps = flt.collateralPerShare();
        uint256 dps = flt.debtPerShare();
        uint256 price = flt.price();
        uint256 lr  = flt.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = ERC20(address(flt)).totalSupply();

        // MintFromDebt
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

        // Check minter balance
        assertEq(
            ERC20(address(flt)).balanceOf(minter),
            mintAmount,
            "invalid minter b"
        );

        // Make sure these values doesn't changes
        assertEq(flt.collateralPerShare(), cps, "invalid cps");
        assertEq(flt.debtPerShare(), dps, "invalid dps");
        assertEq(flt.price(), price, "invalid price");
        uint256 currentLR = flt.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(
            ERC20(address(flt)).totalSupply(),
            ts + mintAmount,
            "invalid ts"
        );

        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            flt.debt().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            flt.collateral().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint doesn't change the price
    function testMintWithLeverageRatioGreaterThan2xViaCollateral() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2.5 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            flt.factory().feeRecipient(),
            0
        );
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            flt.factory().feeRecipient(),
            0
        );

        // Make sure these values does not change after mint
        uint256 cps = flt.collateralPerShare();
        uint256 dps = flt.debtPerShare();
        uint256 price = flt.price();
        uint256 lr  = flt.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = ERC20(address(flt)).totalSupply();

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
        flt.collateral().transfer(address(flt), amountIn);
        flt.mintc(mintAmount, minter, minter);

        // Check minter balance
        assertEq(
            ERC20(address(flt)).balanceOf(minter),
            mintAmount,
            "invalid minter b"
        );

        // Make sure these values doesn't changes
        assertEq(flt.collateralPerShare(), cps, "invalid cps");
        assertEq(flt.debtPerShare(), dps, "invalid dps");
        assertEq(flt.price(), price, "invalid price");
        uint256 currentLR = flt.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(
            ERC20(address(flt)).totalSupply(),
            ts + mintAmount,
            "invalid ts"
        );

        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            flt.collateral().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            flt.debt().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint twice doesn't change the price
    function testMintTwiceViaDebt() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2.5 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            flt.factory().feeRecipient(),
            0
        );
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            flt.factory().feeRecipient(),
            0
        );

        // Make sure these values does not change after mint
        uint256 cps = flt.collateralPerShare();
        uint256 dps = flt.debtPerShare();
        uint256 price = flt.price();
        uint256 lr  = flt.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = ERC20(address(flt)).totalSupply();

        // MintFromDebt
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;

        // First
        uint256 amountIn = getAmountIn(
            address(flt),
            mintAmount,
            address(flt.debt())
        );
        setBalance(address(flt.debt()), data.debtSlot, minter, amountIn);
        flt.debt().transfer(address(flt), amountIn);
        flt.mintd(mintAmount, minter, minter);

        // Second
        amountIn = getAmountIn(
            address(flt),
            mintAmount,
            address(flt.debt())
        );
        setBalance(address(flt.debt()), data.debtSlot, minter, amountIn);
        flt.debt().transfer(address(flt), amountIn);
        flt.mintd(mintAmount, minter, minter);

        // Check minter balance
        assertEq
            (ERC20(address(flt)).balanceOf(minter),
            2*mintAmount,
            "invalid minter b"
        );

        // Make sure these values doesn't changes
        assertEq(flt.collateralPerShare(), cps, "invalid cps");
        assertEq(flt.debtPerShare(), dps, "invalid dps");
        assertEq(flt.price(), price, "invalid price");
        uint256 currentLR = flt.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(
            ERC20(address(flt)).totalSupply(),
            ts + (2*mintAmount),
            "invalid ts"
        );
        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            flt.debt().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            flt.collateral().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint twice doesn't change the price
    function testMintTwiceViaCollateral() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2.5 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            flt.factory().feeRecipient(),
            0
        );
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            flt.factory().feeRecipient(),
            0
        );

        // Make sure these values does not change after mint
        uint256 cps = flt.collateralPerShare();
        uint256 dps = flt.debtPerShare();
        uint256 price = flt.price();
        uint256 lr  = flt.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = ERC20(address(flt)).totalSupply();

        // MintFromDebt
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;

        // First
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
        flt.collateral().transfer(address(flt), amountIn);
        flt.mintc(mintAmount, minter, minter);

        // Second
        amountIn = getAmountIn(
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
        flt.collateral().transfer(address(flt), amountIn);
        flt.mintc(mintAmount, minter, minter);

        // Check minter balance
        assertEq(
            ERC20(address(flt)).balanceOf(minter),
            2*mintAmount,
            "invalid minter b"
        );

        // Make sure these values doesn't changes
        assertEq(flt.collateralPerShare(), cps, "invalid cps");
        assertEq(flt.debtPerShare(), dps, "invalid dps");
        assertEq(flt.price(), price, "invalid price");
        uint256 currentLR = flt.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(
            ERC20(address(flt)).totalSupply(),
            ts + (2*mintAmount),
            "invalid ts"
        );
        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            flt.collateral().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            flt.debt().balanceOf(flt.factory().feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint are refunded
    function testMintRefundViaDebt() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);

        // MintFromDebt
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;

        // First
        uint256 amountIn = getAmountIn(
            address(flt),
            mintAmount,
            address(flt.debt())
        );
        setBalance(address(flt.debt()), data.debtSlot, minter, 2*amountIn);
        flt.debt().transfer(address(flt), 2*amountIn);
        flt.mintd(mintAmount, minter, minter);

        // Check minter balance
        assertEq(flt.debt().balanceOf(minter), amountIn, "invalid balance");
    }

    /// @notice Make sure mint are refunded
    function testMintRefundViaCollateral() public {
        // Get data
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2 ether);

        // MintFromDebt
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;

        // First
        uint256 amountIn = getAmountIn(
            address(flt),
            mintAmount,
            address(flt.collateral())
        );
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            minter,
            2*amountIn
        );
        flt.collateral().transfer(address(flt), 2*amountIn);
        flt.mintc(mintAmount, minter, minter);

        // Check minter balance
        assertEq(
            flt.collateral().balanceOf(minter),
            amountIn,
            "invalid balance"
        );
    }

}
