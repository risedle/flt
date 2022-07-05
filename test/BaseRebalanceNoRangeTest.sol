// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { IFLT } from "../src/interfaces/IFLT.sol";
import { IFLTNoRange } from "../src/interfaces/IFLTNoRange.sol";
import { FLTSinglePairNoRange } from "../src/FLTSinglePairNoRange.sol";

import { BaseTest } from "./BaseTest.sol";

abstract contract BaseRebalanceNoRangeTest is BaseTest {

    using FixedPointMathLib for uint256;

    /// @notice Make sure leverage up revert if leverage ratio in range
    function testPushCollateralRevertIfLeverageRatioInRange() public {
        // Deploy and initialize 2x leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2.1 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.Balance.selector
            )
        );
        flt.pushc();
    }

    /// @notice Make sure leverage down revert if leverage ratio in range
    function testPushDebtRevertIfLeverageRatioInRange() public {
        // Deploy and initialize 2x leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 1.9 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.Balance.selector
            )
        );
        flt.pushd();
    }

    /// @notice Make sure leveraging up revert if no collateral send
    function testPushCollateralRevertIfAmountInIsZero() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 1.5 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountInTooLow.selector
            )
        );
        flt.pushc();
    }

    /// @notice Make sure leveraging down revert if no debt send
    function testPushDebtRevertIfAmountInIsZero() public {
        // Deploy and initialize 2.6 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2.6 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.AmountInTooLow.selector
            )
        );
        flt.pushd();
    }

    /// @notice Make sure leveraging up revert if amount in greater than max
    function testPushCollateralRevertIfAmountInGreaterThanMaxAmountIn() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 1.5 ether);

        // Send some collateral to contract
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            address(this),
            1_000_000 ether
        );
        ERC20(address(flt.collateral())).transfer(
            address(flt),
            1_000_000 ether
        );

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLTNoRange.AmountInTooHigh.selector
            )
        );
        flt.pushc();
    }

    /// @notice Make sure leveraging down revert if amount in less than min
    function testPushDebtRevertIfAmountInGreaterThanMaxAmountIn() public {
        // Deploy and initialize 2.6 leverage ratio
        Data memory data = getData();
        IFLT flt = deployAndInitialize(data, 2.6 ether);

        // Send some collateral to contract
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            1_000_000 ether
        );
        ERC20(address(flt.debt())).transfer(address(flt), 1_000_000 ether);

        // Push collateral to leverage up; this should be revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLTNoRange.AmountInTooHigh.selector
            )
        );
        flt.pushd();
    }

    function getLeverageUpMaxInOut(IFLT _token)
        internal
        view
        returns (uint256 _maxAmountIn, uint256 _maxAmountOut, uint256 _fee)
    {
        uint256 ts = ERC20(address(_token)).totalSupply();
        uint256 step = 2 ether - _token.leverageRatio();
        uint256 maxAmountInETH = step.mulWadDown(
            _token.value(ts)
        );
        _maxAmountIn = _token.oracleAdapter().totalValue(
            address(0),
            address(_token.collateral()),
            maxAmountInETH
        );
        _maxAmountOut = _token.oracleAdapter().totalValue(
            address(_token.collateral()),
            address(_token.debt()),
            _maxAmountIn
        );
        _fee = _token.fees().mulWadDown(_maxAmountOut);
    }

    function getLeverageUpOut(IFLT _token, uint256 _amountIn)
        internal
        view
        returns (uint256 _amountOut, uint256 _fee)
    {
        _amountOut = _token.oracleAdapter().totalValue(
            address(_token.collateral()),
            address(_token.debt()),
            _amountIn
        );
        _fee = _token.fees().mulWadDown(_amountOut);
    }

    /// @notice Make sure leveraging up run as expected
    function testPushCollateral() public {
        // Deploy and initialize 1.5 leverage ratio
        Data memory data = getData();
        IFLT _flt = deployAndInitialize(data, 1.5 ether);
        FLTSinglePairNoRange flt = FLTSinglePairNoRange(address(_flt));

        uint256 tc = flt.totalCollateral();
        uint256 td = flt.totalDebt();
        uint256 p = flt.price();
        uint256 ts = flt.totalSupply();

        // Send some collateral to contract
        (
            uint256 maxAmountIn,
            uint256 maxAmountOut,
            uint256 fee
        ) = getLeverageUpMaxInOut(_flt);
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            address(this),
            maxAmountIn
        );

        // Push collateral to leverage up twice
        uint256 half = uint256(0.5 ether).mulWadDown(maxAmountIn);
        flt.collateral().transfer(address(flt), half);
        flt.pushc();

        (maxAmountIn, ,) = getLeverageUpMaxInOut(_flt);
        setBalance(
            address(flt.collateral()),
            data.collateralSlot,
            address(this),
            maxAmountIn
        );
        flt.collateral().transfer(address(flt), maxAmountIn);
        flt.pushc();

        // Make sure leverage ratio is up
        assertGt(flt.leverageRatio(), 2 ether - 10, "too low");
        assertLt(flt.leverageRatio(), 2 ether + 10, "too high");

        // Make sure total collateral and debt is increased
        uint256 expected = tc + half + maxAmountIn;
        uint256 tolerance = uint256(0.005 ether).mulWadDown(expected);
        assertGt(
            flt.totalCollateral(),
            expected - tolerance,
            "tc too low"
        );
        assertLt(
            flt.totalCollateral(),
            expected + tolerance,
            "tc too high"
        );


        expected = td + maxAmountOut;
        tolerance = uint256(0.005 ether).mulWadDown(expected);
        assertGt(
            flt.totalDebt(),
            expected - tolerance,
            "td too low"
        );
        assertLt(
            flt.totalDebt(),
            expected + tolerance,
            "td too high"
        );

        // Make sure price doesn't change
        uint256 cp = flt.price();
        tolerance = uint256(0.01 ether).mulWadDown(p);
        assertGt(cp, p - tolerance, "p too low");
        assertLt(cp, p + tolerance, "p too high");

        // Make sure total supply doesn't change
        assertEq(flt.totalSupply(), ts, "invalid ts");

        // Make sure user receive debt token
        expected = maxAmountOut - fee;
        tolerance = uint256(0.005 ether).mulWadDown(expected);
        assertGt(
            flt.debt().balanceOf(address(this)),
            expected - tolerance,
            "balance too low"
        );
        assertLt(
            flt.debt().balanceOf(address(this)),
            expected + tolerance,
            "balance too high"
        );
        assertGt(
            flt.debt().balanceOf(flt.factory().feeRecipient()),
            fee - 2,
            "fee too low"
        );
        assertLt(
            flt.debt().balanceOf(flt.factory().feeRecipient()),
            fee + 2,
            "fee too high"
        );
    }

    function getLeverageDownMaxInOut(IFLT _token)
        internal
        view
        returns (uint256 _maxAmountIn, uint256 _maxAmountOut, uint256 _fee)
    {
        uint256 ts = ERC20(address(_token)).totalSupply();
        uint256 step = _token.leverageRatio() - 2 ether;
        uint256 maxAmountInETH = step.mulWadDown(
            _token.value(ts)
        );
        _maxAmountIn = _token.oracleAdapter().totalValue(
            address(0),
            address(_token.debt()),
            maxAmountInETH
        );
        _maxAmountOut = _token.oracleAdapter().totalValue(
            address(_token.debt()),
            address(_token.collateral()),
            _maxAmountIn
        );
        _fee = _token.fees().mulWadDown(_maxAmountOut);
    }

    /// @notice Make sure leveraging down run as expected
    function testPushDebt() public {
        // Deploy and initialize 2.6 leverage ratio
        Data memory data = getData();
        IFLT _flt = deployAndInitialize(data, 2.6 ether);
        FLTSinglePairNoRange flt = FLTSinglePairNoRange(address(_flt));

        uint256 tc = flt.totalCollateral();
        uint256 td = flt.totalDebt();
        uint256 p = flt.price();
        uint256 ts = flt.totalSupply();

        // Send some debt to contract
        (
            uint256 maxAmountIn,
            uint256 maxAmountOut,
            uint256 fee
        ) = getLeverageDownMaxInOut(_flt);
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            maxAmountIn
        );

        // Push debt to leverage down twice
        uint256 half = uint256(0.5 ether).mulWadDown(maxAmountIn);
        flt.debt().transfer(address(flt), half);
        flt.pushd();

        (maxAmountIn, ,) = getLeverageDownMaxInOut(_flt);
        setBalance(
            address(flt.debt()),
            data.debtSlot,
            address(this),
            maxAmountIn
        );
        flt.debt().transfer(address(flt), maxAmountIn);
        flt.pushd();

        // Make sure leverage ratio is down
        assertGt(flt.leverageRatio(), 2 ether - 10, "too low");
        assertLt(flt.leverageRatio(), 2 ether + 10, "too high");

        // Make sure total collateral and debt is decreased
        uint256 expected = td - (half + maxAmountIn);
        uint256 tolerance = uint256(0.005 ether).mulWadDown(expected);
        assertGt(
            flt.totalDebt(),
            expected - tolerance,
            "td too low"
        );
        assertLt(
            flt.totalDebt(),
            expected + tolerance,
            "td too high"
        );

        expected = tc - (maxAmountOut);
        tolerance = uint256(0.005 ether).mulWadDown(expected);
        assertGt(
            flt.totalCollateral(),
            expected - tolerance,
            "tc too low"
        );
        assertLt(
            flt.totalCollateral(),
            expected + tolerance,
            "tc too high"
        );


        // Make sure price doesn't change
        expected = flt.price();
        tolerance = uint256(0.01 ether).mulWadDown(p);
        assertGt(expected, p - tolerance, "p too low");
        assertLt(expected, p + tolerance, "p too high");

        // Make sure total supply doesn't change
        assertEq(flt.totalSupply(), ts, "invalid ts");

        // Make sure user receive collateral token
        expected = maxAmountOut - fee;
        tolerance = uint256(0.005 ether).mulWadDown(expected);
        assertGt(
            flt.collateral().balanceOf(address(this)),
            expected - tolerance,
            "balance too low"
        );
        assertLt(
            flt.collateral().balanceOf(address(this)),
            expected + tolerance,
            "balance too high"
        );
        assertGt(
            flt.collateral().balanceOf(flt.factory().feeRecipient()),
            fee - 2,
            "fee too low"
        );
        assertLt(
            flt.collateral().balanceOf(flt.factory().feeRecipient()),
            fee + 2,
            "fee too high"
        );
    }

}
