// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { Owned } from "solmate/auth/Owned.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { IFLT } from "../src/interfaces/IFLT.sol";
import { FLTSinglePair } from "../src/FLTSinglePair.sol";

import { BaseTest } from "./BaseTest.sol";

abstract contract BaseSinglePair is BaseTest {
    /// ███ Libraries ████████████████████████████████████████████████████████

    using FixedPointMathLib for uint256;


    /// ███ FLTSinglePair utilities ██████████████████████████████████████████

    /// @notice Get initialization params for single pair FLT
    function getInitializationParams(
        address _token,
        uint256 _totalCollateral,
        uint256 _lr,
        uint256 _initialPriceInETH
    ) internal override view returns (
        uint256 _totalDebt,
        uint256 _amountSend,
        uint256 _shares
    ) {
        FLTSinglePair _flt = FLTSinglePair(_token);

        address[] memory path = new address[](2);
        path[0] = address(_flt.debt());
        path[1] = address(_flt.collateral());
        uint256 amountIn = _flt.router().getAmountsIn(
            _totalCollateral,
            path
        )[0];
        uint256 tcv = _flt.oracleAdapter().totalValue(
            address(_flt.collateral()),
            address(_flt.debt()),
            _totalCollateral
        );
        _totalDebt = (tcv.mulWadDown(_lr) - tcv).divWadDown(_lr);
        _amountSend = amountIn - _totalDebt;
        uint256 amountSendValue = _flt.oracleAdapter().totalValue(
            address(_flt.debt()),
            address(0),
            _amountSend
        );
        _shares = amountSendValue.divWadDown(_initialPriceInETH);
    }


    /// @notice Make sure FLT cannot be deployed twice
    function testDeployRevertIfDeployedTwice() public {
        // Get data
        Data memory data = getData();

        // Deploy the FLT
        IFLT _flt = data.factory.create(
            data.name,
            data.symbol,
            data.deploymentData,
            data.implementation
        );

        // Deploy again; should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.Deployed.selector
            )
        );
        _flt.deploy(
            address(data.factory),
            data.name,
            data.symbol,
            data.deploymentData
        );
    }

    /// @notice getAmountIn via debt token for single pair
    function getAmountInViaDebt(
        FLTSinglePair _token,
        uint256 _shares
    ) internal view returns (uint256 _amountIn) {
        // Get collateral amount and debt amount
        (uint256 ca, uint256 da) = _token.sharesToUnderlying(_shares);

        address[] memory path = new address[](2);
        path[0] = address(_token.debt());
        path[1] = address(_token.collateral());
        uint256 repayAmount = _token.router().getAmountsIn(ca, path)[0];
        _amountIn = repayAmount - da;
        uint256 feeAmount = _token.fees().mulWadDown(_amountIn);
        _amountIn = _amountIn + feeAmount;
    }

    /// @notice getAmountIn via collateral
    function getAmountInViaCollateral(
        FLTSinglePair _token,
        uint256 _shares
    ) internal view returns (uint256 _amountIn) {
        // Get collateral amount and debt amount
        (uint256 ca, uint256 da) = _token.sharesToUnderlying(_shares);

        address[] memory path = new address[](2);
        path[0] = address(_token.debt());
        path[1] = address(_token.collateral());
        uint256 borrowAmount = _token.router().getAmountsOut(da, path)[1];
        _amountIn = ca - borrowAmount;
        uint256 feeAmount = _token.fees().mulWadDown(_amountIn);
        _amountIn = _amountIn + feeAmount;
    }

    /// @notice Get required amount in order to mint the token
    function getAmountIn(
        address _token,
        uint256 _shares,
        address _tokenIn
    ) internal override view returns (uint256 _amountIn) {
        FLTSinglePair _flt = FLTSinglePair(_token);

        if (_tokenIn == address(_flt.debt())) {
            return getAmountInViaDebt(_flt, _shares);
        }

        if (_tokenIn == address(_flt.collateral())) {
            return getAmountInViaCollateral(_flt, _shares);
        }

        revert("invalid tokenIn");
    }

    /// @notice Given amount of FLT, get the debt output
    function getAmountOutViaDebt(
        FLTSinglePair _token,
        uint256 _shares
    ) internal view returns (uint256 _amountOut) {
        (uint256 ca, uint256 da) = _token.sharesToUnderlying(_shares);
        address[] memory path = new address[](2);
        path[0] = address(_token.collateral());
        path[1] = address(_token.debt());
        uint256 borrowAmount = _token.router().getAmountsOut(ca, path)[1];
        _amountOut = borrowAmount - da;
    }


    /// @notice Given amount of Rise token, get the collateral output
    function getAmountOutViaCollateral(
        FLTSinglePair _token,
        uint256 _shares
    ) internal view returns (uint256 _amountOut) {
        (uint256 ca, uint256 da) = _token.sharesToUnderlying(_shares);
        address[] memory path = new address[](2);
        path[0] = address(_token.collateral());
        path[1] = address(_token.debt());
        uint256 repayAmount = _token.router().getAmountsIn(da, path)[0];
        _amountOut = ca - repayAmount;
    }

    /// @notice Get amount out given amount of rise token
    function getAmountOut(
        address _token,
        uint256 _shares,
        address _tokenOut
    ) internal override view returns (uint256 _amountOut) {
        FLTSinglePair _flt = FLTSinglePair(_token);

        if (_tokenOut == address(_flt.debt())) {
            return getAmountOutViaDebt(_flt, _shares);
        }

        if (_tokenOut == address(_flt.collateral())) {
            return getAmountOutViaCollateral(_flt, _shares);
        }

        revert("invalid tokenOut");
    }

    /// @notice Make sure only owner can execute the setParams
    function testSetParamsRevertIfNonOwnerExecute() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        // Transfer ownership
        address newOwner = vm.addr(1);
        Owned(address(flt)).setOwner(newOwner);

        vm.expectRevert("UNAUTHORIZED");
        flt.setParams(0, 0, 0, 0, 0);
    }

    /// @notice Make sure revert if min leverage ratio is below 1.2x
    function testSetParamsRevertIfMinLeverageRatioTooLow() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.InvalidLeverageRatio.selector
            )
        );
        flt.setParams(1.1 ether, 0, 0, 0, 0);
    }

    /// @notice Make sure revert if max leverage ratio is above 3x
    function testSetParamsRevertIfMaxLeverageRatioTooHigh() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.InvalidLeverageRatio.selector
            )
        );
        flt.setParams(1.5 ether, 4 ether, 0, 0, 0);
    }

    /// @notice Make sure revert if min max leverage ratio
    function testSetParamsRevertIfMinMaxLeverageRatioInvaid() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.InvalidLeverageRatio.selector
            )
        );
        flt.setParams(4 ether, 2 ether, 0, 0, 0);
    }

    /// @notice Make sure revert if step is too low
    function testSetParamsRevertIfDeltaTooLow() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.InvalidLeverageRatio.selector
            )
        );
        flt.setParams(1.6 ether, 1.9 ether, 0.4 ether, 0, 0);
    }

    /// @notice Make sure revert if step is too low
    function testSetParamsRevertIfStepTooLow() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.InvalidRebalancingStep.selector
            )
        );
        flt.setParams(1.6 ether, 2.5 ether, 0.01 ether, 0, 0);
    }

    /// @notice Make sure revert if step is too high
    function testSetParamsRevertIfStepTooHigh() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.InvalidRebalancingStep.selector
            )
        );
        flt.setParams(1.6 ether, 2.5 ether, 0.6 ether, 0, 0);
    }

    /// @notice Make sure revert if discount is too low
    function testSetParamsRevertIfDiscountTooLow() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.InvalidDiscount.selector
            )
        );
        flt.setParams(1.6 ether, 2.5 ether, 0.4 ether, 0.000001 ether, 0);
    }

    /// @notice Make sure revert if discount is too high
    function testSetParamsRevertIfDiscountTooHigh() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.InvalidDiscount.selector
            )
        );
        flt.setParams(1.6 ether, 2.5 ether, 0.4 ether, 0.1 ether, 0);
    }

    /// @notice Make sure owner can set params
    function testSetParams() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        flt.setParams(1.3 ether, 2.9 ether, 0.4 ether, 0.003 ether, 3 ether);
        assertEq(flt.minLeverageRatio(), 1.3 ether, "invalid min lr");
        assertEq(flt.maxLeverageRatio(), 2.9 ether, "invalid max lr");
        assertEq(flt.step(), 0.4 ether, "invalid step");
        assertEq(flt.discount(), 0.003 ether, "invalid discount");
        assertEq(flt.maxMint(), 3 ether, "invalid maxMint");
    }


    /// @notice Make sure getLeveragingUpInOut return correctly
    function testGetLeveragingUpInOut() public {
        // Deploy and initialize 1.5x token
        Data memory data = getData();
        IFLT token = deployAndInitialize(data, 1.5 ether);

        // Get in and out
        (uint256 amountIn, uint256 amountOut) = getLeveragingUpInOut(token);

        // Make sure value amountOut is equal to amountIn value + discount
        uint256 valueAmountIn = token.oracleAdapter().totalValue(
            address(token.collateral()),
            address(token.debt()),
            amountIn
        );
        uint256 discount = token.discount().mulWadDown(valueAmountIn);
        uint256 expectedAmountOut = valueAmountIn + discount;
        uint256 tolerance = uint256(0.005 ether).mulWadDown(expectedAmountOut);
        assertGt(amountOut, expectedAmountOut - tolerance);
        assertLt(amountOut, expectedAmountOut + tolerance);
    }


    /// @notice Make sure getLeveragingDownInOut return correctly
    function testGetLeveragingDownInOut() public {
        // Deploy and initialize 2.6x token
        Data memory data = getData();
        IFLT token = deployAndInitialize(data, 2.6 ether);

        // Get in and out
        (uint256 amountIn, uint256 amountOut) = getLeveragingDownInOut(token);

        // Make sure value amountOut is equal to amountIn value + discount
        uint256 valueAmountIn = token.oracleAdapter().totalValue(
            address(token.debt()),
            address(token.collateral()),
            amountIn
        );
        uint256 discount = token.discount().mulWadDown(valueAmountIn);
        uint256 expectedAmountOut = valueAmountIn + discount;
        uint256 tolerance = uint256(0.005 ether).mulWadDown(expectedAmountOut);
        assertGt(amountOut, expectedAmountOut - tolerance);
        assertLt(amountOut, expectedAmountOut + tolerance);
    }

    /// @notice Make sure anyone can run increase allowance
    function testIncreaseAllowance() public {
        Data memory data = getData();
        IFLT flt = deploy(data);
        flt.increaseAllowance();
        flt.increaseAllowance();
        flt.increaseAllowance();
        flt.increaseAllowance();
        flt.increaseAllowance();
    }

}
