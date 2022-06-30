// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { RiseToken } from "../src/RiseToken.sol";
import { IRiseToken } from "../src/interfaces/IRiseToken.sol";

import { BaseTest } from "./BaseTest.sol";

abstract contract BaseMintTest is BaseTest {

    /// @notice Make sure pool is seeded
    function _seedPool() internal {
        // Get data
        Data memory data = getData();

        // Add supply to Risedle Pool
        setBalance(
            address(data.debt),
            data.debtSlot,
            address(this),
            data.debtSupplyAmount
        );
        data.debt.approve(address(data.fDebt), data.debtSupplyAmount);
        data.fDebt.mint(data.debtSupplyAmount);
    }

    /// @notice Make sure it revert when token is not initialized
    function testMintRevertIfNotInitializedViaDebt() public {
        // Get data
        Data memory data = getData();

        // Seed pool
        _seedPool();

        // Deploy Rise Token
        RiseToken riseToken = deploy(data);

        // MintFromDebt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.Uninitialized.selector
            )
        );
        riseToken.mintd(1 ether, address(this), address(this));
    }

    /// @notice Make sure it revert when token is not initialized
    function testMintRevertIfNotInitializedViaCollateral() public {
        // Get data
        Data memory data = getData();

        // Seed pool
        _seedPool();

        // Deploy Rise Token
        RiseToken riseToken = deploy(data);

        // MintFromDebt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.Uninitialized.selector
            )
        );
        riseToken.mintc(1 ether, address(this), address(this));
    }

    /// @notice Make sure it revert when mint amount is more than max mint
    function testMintRevertIfMoreThanMaxMintViaDebt() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // Set max mint to 1 ether
        riseToken.setParams(
            riseToken.minLeverageRatio(),
            riseToken.maxLeverageRatio(),
            riseToken.step(),
            riseToken.discount(),
            0.5 ether
        );

        // MintFromDebt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountOutTooHigh.selector
            )
        );
        riseToken.mintd(2 ether, address(this), address(this));
    }

    /// @notice Make sure it revert when mint amount is more than max mint
    function testMintRevertIfMoreThanMaxMintViaCollateral() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // Set max mint to 1 ether
        riseToken.setParams(
            riseToken.minLeverageRatio(),
            riseToken.maxLeverageRatio(),
            riseToken.step(),
            riseToken.discount(),
            0.5 ether
        );

        // MintFromDebt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountOutTooHigh.selector
            )
        );
        riseToken.mintc(2 ether, address(this), address(this));
    }

    /// @notice Make sure it revert when mint amount is zero
    function testMintRevertIfMintAmountIsZeroViaDebt() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // MintFromDebt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountOutTooLow.selector
            )
        );
        riseToken.mintd(0, address(this), address(this));
    }

    /// @notice Make sure it revert when mint amount is zero
    function testMintRevertIfMintAmountIsZeroViaCollateral() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // MintFromDebt; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountOutTooLow.selector
            )
        );
        riseToken.mintc(0, address(this), address(this));
    }

    /// @notice Make sure it revert when required amount is not send
    function testMintRevertIfRequiredAmountNotReceivedViaDebt() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // MintFromDebt; this should revert
        uint256 mintAmount = 5 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountInTooLow.selector
            )
        );
        riseToken.mintd(mintAmount, address(this), address(this));
    }

    /// @notice Make sure it revert when required amount is not send
    function testMintRevertIfRequiredAmountNotReceivedViaCollateral() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // MintFromDebt; this should revert
        uint256 mintAmount = 5 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountInTooLow.selector
            )
        );
        riseToken.mintc(mintAmount, address(this), address(this));
    }

    /// @notice Make sure mint doesn't change the price
    function testMintWithLeverageRatio2xViaDebt() public {
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

        // Make sure these values does not change after mint
        uint256 cps = riseToken.collateralPerShare();
        uint256 dps = riseToken.debtPerShare();
        uint256 price = riseToken.price();
        uint256 lr  = riseToken.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = riseToken.totalSupply();

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

        // Check minter balance
        assertEq(riseToken.balanceOf(minter), mintAmount, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
        assertEq(riseToken.price(), price, "invalid price");
        uint256 currentLR = riseToken.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(riseToken.totalSupply(), ts + mintAmount, "invalid ts");

        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            data.debt.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            data.collateral.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint doesn't change the price
    function testMintWithLeverageRatio2xViaCollateral() public {
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

        // Make sure these values does not change after mint
        uint256 cps = riseToken.collateralPerShare();
        uint256 dps = riseToken.debtPerShare();
        uint256 price = riseToken.price();
        uint256 lr  = riseToken.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = riseToken.totalSupply();

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

        // Check minter balance
        assertEq(riseToken.balanceOf(minter), mintAmount, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
        assertEq(riseToken.price(), price, "invalid price");
        uint256 currentLR = riseToken.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(riseToken.totalSupply(), ts + mintAmount, "invalid ts");

        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            data.collateral.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            data.debt.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint doesn't change the price
    function testMintWithLeverageRatioLessThan2xViaDebt() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 1.6 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(data.debt),
            data.debtSlot,
            data.factory.feeRecipient(),
            0
        );

        // Make sure these values does not change after mint
        uint256 cps = riseToken.collateralPerShare();
        uint256 dps = riseToken.debtPerShare();
        uint256 price = riseToken.price();
        uint256 lr  = riseToken.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = riseToken.totalSupply();

        // MintFromDebt
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

        // Check minter balance
        assertEq(riseToken.balanceOf(minter), mintAmount, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
        assertEq(riseToken.price(), price, "invalid price");
        uint256 currentLR = riseToken.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(riseToken.totalSupply(), ts + mintAmount, "invalid ts");

        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            data.debt.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            data.collateral.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint doesn't change the price
    function testMintWithLeverageRatioLessThan2xViaCollateral() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 1.6 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(data.collateral),
            data.collateralSlot,
            data.factory.feeRecipient(),
            0
        );

        // Make sure these values does not change after mint
        uint256 cps = riseToken.collateralPerShare();
        uint256 dps = riseToken.debtPerShare();
        uint256 price = riseToken.price();
        uint256 lr  = riseToken.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = riseToken.totalSupply();

        // MintFromDebt
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

        // Check minter balance
        assertEq(riseToken.balanceOf(minter), mintAmount, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
        assertEq(riseToken.price(), price, "invalid price");
        uint256 currentLR = riseToken.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(riseToken.totalSupply(), ts + mintAmount, "invalid ts");

        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            data.collateral.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            data.debt.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint doesn't change the price
    function testMintWithLeverageRatioGreaterThan2xViaDebt() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2.5 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(data.debt),
            data.debtSlot,
            data.factory.feeRecipient(),
            0
        );

        // Make sure these values does not change after mint
        uint256 cps = riseToken.collateralPerShare();
        uint256 dps = riseToken.debtPerShare();
        uint256 price = riseToken.price();
        uint256 lr  = riseToken.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = riseToken.totalSupply();

        // MintFromDebt
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

        // Check minter balance
        assertEq(riseToken.balanceOf(minter), mintAmount, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
        assertEq(riseToken.price(), price, "invalid price");
        uint256 currentLR = riseToken.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(riseToken.totalSupply(), ts + mintAmount, "invalid ts");

        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            data.debt.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            data.collateral.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint doesn't change the price
    function testMintWithLeverageRatioGreaterThan2xViaCollateral() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2.5 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(data.collateral),
            data.collateralSlot,
            data.factory.feeRecipient(),
            0
        );

        // Make sure these values does not change after mint
        uint256 cps = riseToken.collateralPerShare();
        uint256 dps = riseToken.debtPerShare();
        uint256 price = riseToken.price();
        uint256 lr  = riseToken.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = riseToken.totalSupply();

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

        // Check minter balance
        assertEq(riseToken.balanceOf(minter), mintAmount, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
        assertEq(riseToken.price(), price, "invalid price");
        uint256 currentLR = riseToken.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(riseToken.totalSupply(), ts + mintAmount, "invalid ts");

        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            data.collateral.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            data.debt.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint twice doesn't change the price
    function testMintTwiceViaDebt() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2.5 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(data.debt),
            data.debtSlot,
            data.factory.feeRecipient(),
            0
        );

        // Make sure these values does not change after mint
        uint256 cps = riseToken.collateralPerShare();
        uint256 dps = riseToken.debtPerShare();
        uint256 price = riseToken.price();
        uint256 lr  = riseToken.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = riseToken.totalSupply();

        // MintFromDebt
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;

        // First
        uint256 amountIn = getAmountIn(
            riseToken,
            mintAmount,
            address(data.debt)
        );
        setBalance(address(data.debt), data.debtSlot, minter, amountIn);
        data.debt.transfer(address(riseToken), amountIn);
        riseToken.mintd(mintAmount, minter, minter);

        // Second
        amountIn = getAmountIn(
            riseToken,
            mintAmount,
            address(data.debt)
        );
        setBalance(address(data.debt), data.debtSlot, minter, amountIn);
        data.debt.transfer(address(riseToken), amountIn);
        riseToken.mintd(mintAmount, minter, minter);

        // Check minter balance
        assertEq(riseToken.balanceOf(minter), 2*mintAmount, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
        assertEq(riseToken.price(), price, "invalid price");
        uint256 currentLR = riseToken.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(riseToken.totalSupply(), ts + (2*mintAmount), "invalid ts");
        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            data.debt.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            data.collateral.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint twice doesn't change the price
    function testMintTwiceViaCollateral() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2.5 ether);

        // Reset fee recipient balance to zero
        setBalance(
            address(data.collateral),
            data.collateralSlot,
            data.factory.feeRecipient(),
            0
        );

        // Make sure these values does not change after mint
        uint256 cps = riseToken.collateralPerShare();
        uint256 dps = riseToken.debtPerShare();
        uint256 price = riseToken.price();
        uint256 lr  = riseToken.leverageRatio();

        // Make sure these values is increased after mint
        uint256 ts = riseToken.totalSupply();

        // MintFromDebt
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;

        // First
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

        // Second
        amountIn = getAmountIn(
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

        // Check minter balance
        assertEq(riseToken.balanceOf(minter), 2*mintAmount, "invalid minter b");

        // Make sure these values doesn't changes
        assertEq(riseToken.collateralPerShare(), cps, "invalid cps");
        assertEq(riseToken.debtPerShare(), dps, "invalid dps");
        assertEq(riseToken.price(), price, "invalid price");
        uint256 currentLR = riseToken.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Make sure total supply is increased
        assertEq(riseToken.totalSupply(), ts + (2*mintAmount), "invalid ts");
        // Make sure fee recipient receive 0.1% of amountIn
        assertGt(
            data.collateral.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
        assertEq(
            data.debt.balanceOf(data.factory.feeRecipient()),
            0,
            "invalid fee recipient"
        );
    }

    /// @notice Make sure mint are refunded
    function testMintRefundViaDebt() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // MintFromDebt
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;

        // First
        uint256 amountIn = getAmountIn(
            riseToken,
            mintAmount,
            address(data.debt)
        );
        setBalance(address(data.debt), data.debtSlot, minter, 2*amountIn);
        data.debt.transfer(address(riseToken), 2*amountIn);
        riseToken.mintd(mintAmount, minter, minter);

        // Check minter balance
        assertEq(data.debt.balanceOf(minter), amountIn, "invalid balance");
    }

    /// @notice Make sure mint are refunded
    function testMintRefundViaCollateral() public {
        // Get data
        Data memory data = getData();
        RiseToken riseToken = deployAndInitialize(data, 2 ether);

        // MintFromDebt
        address minter = vm.addr(1);
        startHoax(minter);
        uint256 mintAmount = 5 ether;

        // First
        uint256 amountIn = getAmountIn(
            riseToken,
            mintAmount,
            address(data.collateral)
        );
        setBalance(
            address(data.collateral),
            data.collateralSlot,
            minter,
            2*amountIn
        );
        data.collateral.transfer(address(riseToken), 2*amountIn);
        riseToken.mintc(mintAmount, minter, minter);

        // Check minter balance
        assertEq(data.collateral.balanceOf(minter), amountIn, "invalid balance");
    }

}
