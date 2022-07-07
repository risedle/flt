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
        } else if (_tokenIn == address(_flt.collateral())) {
            return getAmountInViaCollateral(_flt, _shares);
        } else revert("invalid tokenIn");
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

    /// @notice Make sure revert if min max leverage ratio
    function testSetParamsRevertIfMinMaxLeverageRatioInvalid() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.InvalidLeverageRatio.selector
            )
        );
        flt.setParams(4 ether, 2 ether, 0, 0, 0);
    }

    /// @notice Make sure revert if max drift is too low
    function testSetParamsRevertIfMaxDriftTooLow() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.InvalidMaxDrift.selector
            )
        );
        flt.setParams(1.6 ether, 1.9 ether, 0.2 ether, 0, 0);
    }

    /// @notice Make sure revert if max drift is too high
    function testSetParamsRevertIfMaxDriftTooHigh() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.InvalidMaxDrift.selector
            )
        );
        flt.setParams(1.6 ether, 1.9 ether, 1 ether, 0, 0);
    }

    /// @notice Make sure revert if incentive is too low
    function testSetParamsRevertIfMaxIncentiveTooLow() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.InvalidMaxIncentive.selector
            )
        );
        flt.setParams(1.6 ether, 2.5 ether, 0.4 ether, 0.000001 ether, 0);
    }

    /// @notice Make sure revert if incentive is too high
    function testSetParamsRevertIfMaxIncentiveTooHigh() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLT.InvalidMaxIncentive.selector
            )
        );
        flt.setParams(1.6 ether, 2.5 ether, 0.4 ether, 0.3 ether, 0);
    }

    /// @notice Make sure owner can set params
    function testSetParams() public {
        Data memory data = getData();
        IFLT flt = deploy(data);

        flt.setParams(1.3 ether, 2.9 ether, 0.4 ether, 0.2 ether, 3 ether);
        assertEq(flt.minLeverageRatio(), 1.3 ether, "invalid min lr");
        assertEq(flt.maxLeverageRatio(), 2.9 ether, "invalid max lr");
        assertEq(flt.maxDrift(), 0.4 ether, "invalid max drift");
        assertEq(flt.maxIncentive(), 0.2 ether, "invalid max incentive");
        assertEq(flt.maxSupply(), 3 ether, "invalid maxSupply");
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
