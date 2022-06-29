// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { RiseToken } from "../src/RiseToken.sol";
import { IRiseToken } from "../src/interfaces/IRiseToken.sol";

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

        // Add supply to Risedle Pool
        setBalance(
            address(data.debt),
            data.debtSlot,
            address(this),
            data.debtSupplyAmount
        );
        data.debt.approve(address(data.fDebt), data.debtSupplyAmount);
        data.fDebt.mint(data.debtSupplyAmount);

        // Deploy Rise Token
        RiseToken riseToken = deploy(data);
        uint256 lr = 2 ether;
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            data,
            lr
        );

        // Transfer `send` amount to riseToken
        setBalance(address(data.debt), data.debtSlot, address(this), send);
        data.debt.transfer(address(riseToken), send);

        // Transfer ownership
        address newOwner = vm.addr(2);
        riseToken.transferOwnership(newOwner);

        // Initialize as non owner, this should revert
        vm.expectRevert("Ownable: caller is not the owner");
        riseToken.initialize(data.totalCollateral, da, shares);
    }

    /// @notice Make sure the transaction revert if executed twice
    function testInitializeRevertIfExecutedTwice() public {
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

        // Deploy Rise Token
        RiseToken riseToken = deploy(data);
        uint256 lr = 2 ether;
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            data,
            lr
        );

        // Transfer `send` amount to riseToken
        setBalance(address(data.debt), data.debtSlot, address(this), send);
        data.debt.transfer(address(riseToken), send);
        riseToken.initialize(data.totalCollateral, da, shares);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.Uninitialized.selector
            )
        );
        riseToken.initialize(data.totalCollateral, da, shares);
    }

    /// @notice Make sure the transaction revert if required amount is not
    //          transfered
    function testInitializeRevertIfNoTransfer() public {
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

        // Deploy Rise Token
        RiseToken riseToken = deploy(data);
        uint256 lr = 2 ether;
        (uint256 da, , uint256 shares) = getInitializationParams(
            data,
            lr
        );

        // Initialize without transfer; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.AmountInTooLow.selector
            )
        );
        riseToken.initialize(data.totalCollateral, da, shares);
    }

    /// @notice Make sure pancakeCall only pair can call
    function testPancakeCallRevertIfCallerIsNotPair() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        RiseToken riseToken = deploy(data);

        // Call the pancake call
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.Unauthorized.selector
            )
        );
        riseToken.pancakeCall(vm.addr(1), 1 ether, 1 ether, bytes("data"));
    }

    /// @notice Make sure uniswapV2Pair only pair can call
    function testUniswapV2CallRevertIfCallerIsNotPair() public {
        // Get data
        Data memory data = getData();

        // Deploy Rise Token
        RiseToken riseToken = deploy(data);

        // Call the Uniswap V2 call
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.Unauthorized.selector
            )
        );
        riseToken.uniswapV2Call(vm.addr(1), 1 ether, 1 ether, bytes("data"));
    }

    /// @notice Make sure initializer get refund
    function testInitializeRefundSender() public {
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

        // Deploy Rise Token
        RiseToken riseToken = deploy(data);
        uint256 lr = 2 ether;
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            data,
            lr
        );

        // Transfer `send` amount to riseToken
        setBalance(address(data.debt), data.debtSlot, address(this), 2*send);
        data.debt.transfer(address(riseToken), 2*send);
        riseToken.initialize(data.totalCollateral, da, shares);

        // Make sure it refunded
        assertEq(data.debt.balanceOf(address(this)), send, "invalid balance");
        assertEq(data.debt.balanceOf(address(riseToken)), 0, "invalid contract");
    }

    /// @notice Make sure 2x have correct states
    function testInitializeWithLeverageRatio2x() public {
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

        // Deploy Rise Token
        RiseToken riseToken = deploy(data);
        uint256 lr = 2 ether;
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            data,
            lr
        );

        // Transfer `send` amount to riseToken
        setBalance(address(data.debt), data.debtSlot, address(this), send);
        data.debt.transfer(address(riseToken), send);
        riseToken.initialize(data.totalCollateral, da, shares);

        // Check the parameters
        assertTrue(riseToken.isInitialized(), "invalid status");

        // Check total collateral
        assertGt(
            riseToken.totalCollateral(),
            data.totalCollateral-2,
            "total collateral too low"
        );
        assertLt(
            riseToken.totalCollateral(),
            data.totalCollateral+2,
            "total collateral too high"
        );

        // Check total debt
        assertEq(
            riseToken.totalDebt(),
            da,
            "invalid total debt"
        );

        // Check total supply
        uint256 totalSupply = riseToken.totalSupply();
        uint256 balance = riseToken.balanceOf(address(this));
        assertTrue(totalSupply > 0, "invalid total supply");
        assertEq(balance, totalSupply, "invalid balance");

        // Check price
        uint256 price = riseToken.price();
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
        uint256 currentLR = riseToken.leverageRatio();
        assertGt(currentLR, lr - 0.0001 ether, "lr too low");
        assertLt(currentLR, lr + 0.0001 ether, "lr too high");

        // Check balance; make sure contract doesn't hold any this token
        assertEq(
            data.collateral.balanceOf(address(riseToken)),
            0,
            "invalid balance"
        );
        assertEq(
            data.debt.balanceOf(address(riseToken)),
            0,
            "invalid balance"
        );
    }

    /// @notice Make sure 1.3x have correct states
    function testInitializeWithLeverageRatioLessThan2x() public {
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

        // Deploy Rise Token
        RiseToken riseToken = deploy(data);
        uint256 lr = 1.3 ether;
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            data,
            lr
        );

        // Transfer `send` amount to riseToken
        setBalance(address(data.debt), data.debtSlot, address(this), send);
        data.debt.transfer(address(riseToken), send);
        riseToken.initialize(data.totalCollateral, da, shares);

        // Check the parameters
        assertTrue(riseToken.isInitialized(), "invalid status");

        // Check total collateral
        assertGt(
            riseToken.totalCollateral(),
            data.totalCollateral-2,
            "total collateral too low"
        );
        assertLt(
            riseToken.totalCollateral(),
            data.totalCollateral+2,
            "total collateral too high"
        );

        // Check total debt
        assertEq(
            riseToken.totalDebt(),
            da,
            "invalid total debt"
        );

        // Check total supply
        uint256 totalSupply = riseToken.totalSupply();
        uint256 balance = riseToken.balanceOf(address(this));
        assertTrue(totalSupply > 0, "invalid total supply");
        assertEq(balance, totalSupply, "invalid balance");

        // Check price
        uint256 price = riseToken.price();
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
        uint256 currentLR = riseToken.leverageRatio();
        require(currentLR > lr - 0.0001 ether, "lr too low");
        require(currentLR < lr + 0.0001 ether, "lr too high");
    }

    /// @notice Make sure 2.6x have correct states
    function testInitializeWithLeverageRatioGreaterThan2x() public {
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

        // Deploy Rise Token
        RiseToken riseToken = deploy(data);
        uint256 lr = 2.6 ether;
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            data,
            lr
        );

        // Transfer `send` amount to riseToken
        setBalance(address(data.debt), data.debtSlot, address(this), send);
        data.debt.transfer(address(riseToken), send);
        riseToken.initialize(data.totalCollateral, da, shares);

        // Check the parameters
        assertTrue(riseToken.isInitialized(), "invalid status");

        // Check total collateral
        assertGt(
            riseToken.totalCollateral(),
            data.totalCollateral-2,
            "total collateral too low"
        );
        assertLt(
            riseToken.totalCollateral(),
            data.totalCollateral+2,
            "total collateral too high"
        );

        // Check total debt
        assertEq(
            riseToken.totalDebt(),
            da,
            "invalid total debt"
        );

        // Check total supply
        uint256 totalSupply = riseToken.totalSupply();
        uint256 balance = riseToken.balanceOf(address(this));
        assertTrue(totalSupply > 0, "invalid total supply");
        assertEq(balance, totalSupply, "invalid balance");

        // Check price
        uint256 price = riseToken.price();
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
        uint256 currentLR = riseToken.leverageRatio();
        require(currentLR > lr - 0.0001 ether, "lr too low");
        require(currentLR < lr + 0.0001 ether, "lr too high");
    }


}
