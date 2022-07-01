// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { IFLT } from "../src/interfaces/IFLT.sol";

import { BaseTest } from "./BaseTest.sol";

/**
 * @title Base Initialize
 * @author bayu <bayu@risedle.com> <github.com/pyk>
 * @notice Compherensive test-case for RISE or DROP token initialization
 */
abstract contract BaseInitializeTest is BaseTest {

    /// ███ Libraries ████████████████████████████████████████████████████████

    using FixedPointMathLib for uint256;


    /// ███ Test cases ███████████████████████████████████████████████████████

    /// @notice Make sure the transaction revert if non-owner execute
    function testInitializeRevertIfNonOwnerExecute() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        IFLT flt = deploy(data);
        uint256 lr = 2 ether;
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            address(flt),
            data.totalCollateral,
            lr,
            data.initialPriceInETH
        );

        // Add supply to Risedle Pool
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            data.debtSupplyAmount
        );
        flt.debt().approve(address(flt.fDebt()), data.debtSupplyAmount);
        flt.fDebt().mint(data.debtSupplyAmount);

        // Transfer `send` amount to flt
        setBalance(address(flt.debt()), data.debtSlot, address(this), send);
        flt.debt().transfer(address(flt), send);

        // Transfer ownership
        address newOwner = vm.addr(2);
        Owned(address(flt)).setOwner(newOwner);

        // Initialize as non owner, this should revert
        vm.expectRevert("UNAUTHORIZED");
        flt.initialize(data.totalCollateral, da, shares);
    }

    /// @notice Make sure the transaction revert if executed twice
    function testInitializeRevertIfExecutedTwice() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        IFLT flt = deploy(data);
        uint256 lr = 2 ether;
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            address(flt),
            data.totalCollateral,
            lr,
            data.initialPriceInETH
        );

        // Add supply to Risedle Pool
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            data.debtSupplyAmount
        );
        flt.debt().approve(address(flt.fDebt()), data.debtSupplyAmount);
        flt.fDebt().mint(data.debtSupplyAmount);


        // Transfer `send` amount to flt
        setBalance(address(flt.debt()), data.debtSlot, address(this), send);
        flt.debt().transfer(address(flt), send);
        flt.initialize(data.totalCollateral, da, shares);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.Uninitialized.selector
            )
        );
        flt.initialize(data.totalCollateral, da, shares);
    }

    /// @notice Make sure the transaction revert if required amount is not
    //          transfered
    function testInitializeRevertIfNoTransfer() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        IFLT flt = deploy(data);
        uint256 lr = 2 ether;
        (uint256 da, , uint256 shares) = getInitializationParams(
            address(flt),
            data.totalCollateral,
            lr,
            data.initialPriceInETH
        );

        // Add supply to Risedle Pool
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            data.debtSupplyAmount
        );
        flt.debt().approve(address(flt.fDebt()), data.debtSupplyAmount);
        flt.fDebt().mint(data.debtSupplyAmount);


        // Initialize without transfer; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountInTooLow.selector
            )
        );
        flt.initialize(data.totalCollateral, da, shares);
    }

    /// @notice Make sure pancakeCall only pair can call
    function testPancakeCallRevertIfCallerIsNotPair() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        IFLT flt = deploy(data);

        // Call the pancake call
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.Unauthorized.selector
            )
        );
        flt.pancakeCall(vm.addr(1), 1 ether, 1 ether, bytes("data"));
    }

    /// @notice Make sure uniswapV2Pair only pair can call
    function testUniswapV2CallRevertIfCallerIsNotPair() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        IFLT flt = deploy(data);

        // Call the Uniswap V2 call
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.Unauthorized.selector
            )
        );
        flt.uniswapV2Call(vm.addr(1), 1 ether, 1 ether, bytes("data"));
    }

    /// @notice Make sure initializer get refund
    function testInitializeRefundSender() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        IFLT flt = deploy(data);
        uint256 lr = 2 ether;
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            address(flt),
            data.totalCollateral,
            lr,
            data.initialPriceInETH
        );

        // Add supply to Risedle Pool
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            data.debtSupplyAmount
        );
        flt.debt().approve(address(flt.fDebt()), data.debtSupplyAmount);
        flt.fDebt().mint(data.debtSupplyAmount);


        // Transfer `send` amount to flt
        setBalance(address(flt.debt()), data.debtSlot, address(this), 2*send);
        flt.debt().transfer(address(flt), 2*send);
        flt.initialize(data.totalCollateral, da, shares);

        // Make sure it refunded
        assertEq(flt.debt().balanceOf(address(this)), send, "invalid balance");
        assertEq(flt.debt().balanceOf(address(flt)), 0, "invalid contract");
    }

    /// @notice Make sure 2x have correct states
    function testInitializeWithLeverageRatio2x() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        IFLT flt = deploy(data);
        uint256 lr = 2 ether;
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            address(flt),
            data.totalCollateral,
            lr,
            data.initialPriceInETH
        );

        // Add supply to Risedle Pool
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            data.debtSupplyAmount
        );
        flt.debt().approve(address(flt.fDebt()), data.debtSupplyAmount);
        flt.fDebt().mint(data.debtSupplyAmount);


        // Transfer `send` amount to flt
        setBalance(address(flt.debt()), data.debtSlot, address(this), send);
        flt.debt().transfer(address(flt), send);
        flt.initialize(data.totalCollateral, da, shares);

        // Check the parameters
        assertTrue(flt.isInitialized(), "invalid status");

        // Check total collateral
        assertGt(
            flt.totalCollateral(),
            data.totalCollateral-2,
            "total collateral too low"
        );
        assertLt(
            flt.totalCollateral(),
            data.totalCollateral+2,
            "total collateral too high"
        );

        // Check total debt
        assertEq(
            flt.totalDebt(),
            da,
            "invalid total debt"
        );

        // Check total supply
        uint256 totalSupply = ERC20(address(flt)).totalSupply();
        uint256 balance = ERC20(address(flt)).balanceOf(address(this));
        assertTrue(totalSupply > 0, "invalid total supply");
        assertEq(balance, totalSupply, "invalid balance");

        // Check price
        uint256 price = flt.price();
        uint256 percentage = 0.02 ether; // 2%
        uint256 tolerance = percentage.mulWadDown(data.initialPriceInETH);
        assertGt(
            price,
            data.initialPriceInETH - tolerance,
            "price too low"
        );
        assertLt(
            price,
            data.initialPriceInETH + tolerance,
            "price too high"
        );

        // Check leverage ratio
        uint256 currentLR = flt.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Check balance; make sure contract doesn't hold any this token
        assertEq(
            flt.collateral().balanceOf(address(flt)),
            0,
            "invalid balance"
        );
        assertEq(
            flt.debt().balanceOf(address(flt)),
            0,
            "invalid balance"
        );
    }

    /// @notice Make sure 1.3x have correct states
    function testInitializeWithLeverageRatioLessThan2x() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        IFLT flt = deploy(data);
        uint256 lr = 1.3 ether;
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            address(flt),
            data.totalCollateral,
            lr,
            data.initialPriceInETH
        );

        // Add supply to Risedle Pool
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            data.debtSupplyAmount
        );
        flt.debt().approve(address(flt.fDebt()), data.debtSupplyAmount);
        flt.fDebt().mint(data.debtSupplyAmount);


        // Transfer `send` amount to flt
        setBalance(address(flt.debt()), data.debtSlot, address(this), send);
        flt.debt().transfer(address(flt), send);
        flt.initialize(data.totalCollateral, da, shares);

        // Check the parameters
        assertTrue(flt.isInitialized(), "invalid status");

        // Check total collateral
        assertGt(
            flt.totalCollateral(),
            data.totalCollateral-2,
            "total collateral too low"
        );
        assertLt(
            flt.totalCollateral(),
            data.totalCollateral+2,
            "total collateral too high"
        );

        // Check total debt
        assertEq(
            flt.totalDebt(),
            da,
            "invalid total debt"
        );

        // Check total supply
        uint256 totalSupply = ERC20(address(flt)).totalSupply();
        uint256 balance = ERC20(address(flt)).balanceOf(address(this));
        assertTrue(totalSupply > 0, "invalid total supply");
        assertEq(balance, totalSupply, "invalid balance");

        // Check price
        uint256 price = flt.price();
        uint256 percentage = 0.03 ether; // 3%
        uint256 tolerance = percentage.mulWadDown(data.initialPriceInETH);
        assertGt(
            price,
            data.initialPriceInETH - tolerance,
            "price too low"
        );
        assertLt(
            price,
            data.initialPriceInETH + tolerance,
            "price too high"
        );

        // Check leverage ratio
        uint256 currentLR = flt.leverageRatio();
        require(currentLR > lr - 0.0001 ether, "lr too low");
        require(currentLR < lr + 0.0001 ether, "lr too high");
    }

    /// @notice Make sure 2.6x have correct states
    function testInitializeWithLeverageRatioGreaterThan2x() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        IFLT flt = deploy(data);
        uint256 lr = 2.6 ether;
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            address(flt),
            data.totalCollateral,
            lr,
            data.initialPriceInETH
        );

        // Add supply to Risedle Pool
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            data.debtSupplyAmount
        );
        flt.debt().approve(address(flt.fDebt()), data.debtSupplyAmount);
        flt.fDebt().mint(data.debtSupplyAmount);

        // Transfer `send` amount to flt
        setBalance(address(flt.debt()), data.debtSlot, address(this), send);
        flt.debt().transfer(address(flt), send);
        flt.initialize(data.totalCollateral, da, shares);

        // Check the parameters
        assertTrue(flt.isInitialized(), "invalid status");

        // Check total collateral
        assertGt(
            flt.totalCollateral(),
            data.totalCollateral-2,
            "total collateral too low"
        );
        assertLt(
            flt.totalCollateral(),
            data.totalCollateral+2,
            "total collateral too high"
        );

        // Check total debt
        assertEq(
            flt.totalDebt(),
            da,
            "invalid total debt"
        );

        // Check total supply
        uint256 totalSupply = ERC20(address(flt)).totalSupply();
        uint256 balance = ERC20(address(flt)).balanceOf(address(this));
        assertTrue(totalSupply > 0, "invalid total supply");
        assertEq(balance, totalSupply, "invalid balance");

        // Check price
        uint256 price = flt.price();
        uint256 percentage = 0.03 ether; // 3%
        uint256 tolerance = percentage.mulWadDown(data.initialPriceInETH);
        assertGt(
            price,
            data.initialPriceInETH - tolerance,
            "price too low"
        );
        assertLt(
            price,
            data.initialPriceInETH + tolerance,
            "price too high"
        );

        // Check leverage ratio
        uint256 currentLR = flt.leverageRatio();
        require(currentLR > lr - 0.0001 ether, "lr too low");
        require(currentLR < lr + 0.0001 ether, "lr too high");
    }
}
