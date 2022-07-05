// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { Owned } from "solmate/auth/Owned.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { IFLT } from "../src/interfaces/IFLT.sol";
import { IFLTNoRange } from "../src/interfaces/IFLTNoRange.sol";
import { FLTSinglePairNoRange } from "../src/FLTSinglePairNoRange.sol";

import { BaseTest } from "./BaseTest.sol";

abstract contract BaseSinglePairNoRange is BaseTest {

    /// ███ Libraries ████████████████████████████████████████████████████████

    using FixedPointMathLib for uint256;

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
        FLTSinglePairNoRange _flt = FLTSinglePairNoRange(_token);

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

    /// @notice getAmountIn via debt token for single pair
    function getAmountInViaDebt(
        FLTSinglePairNoRange _token,
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
        FLTSinglePairNoRange _token,
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
        FLTSinglePairNoRange _flt = FLTSinglePairNoRange(_token);

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
        FLTSinglePairNoRange _token,
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
        FLTSinglePairNoRange _token,
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
        FLTSinglePairNoRange _flt = FLTSinglePairNoRange(_token);

        if (_tokenOut == address(_flt.debt())) {
            return getAmountOutViaDebt(_flt, _shares);
        }

        if (_tokenOut == address(_flt.collateral())) {
            return getAmountOutViaCollateral(_flt, _shares);
        }

        revert("invalid tokenOut");
    }

    /// @notice Make sure only owner can execute the setMaxSupply
    function testSetMaxSupplyRevertIfNonOwnerExecute() public {
        Data memory data = getData();
        FLTSinglePairNoRange flt = FLTSinglePairNoRange(address(deploy(data)));

        // Transfer ownership
        address newOwner = vm.addr(1);
        Owned(address(flt)).setOwner(newOwner);

        vm.expectRevert("UNAUTHORIZED");
        flt.setMaxSupply(0);
    }

    /// @notice revert if value is the same
    function testSetMaxSupplyRevertIfValueDoesNotChange() public {
        Data memory data = getData();
        FLTSinglePairNoRange flt = FLTSinglePairNoRange(address(deploy(data)));

        vm.expectRevert(
            abi.encodeWithSelector(
                IFLTNoRange.InvalidMaxSupply.selector
            )
        );
        flt.setMaxSupply(type(uint256).max);
    }

    /// @notice Make sure owner can update max supply
    function testSetMaxSupply() public {
        Data memory data = getData();
        FLTSinglePairNoRange flt = FLTSinglePairNoRange(address(deploy(data)));

        flt.setMaxSupply(2 ether);
        assertEq(flt.maxSupply(), 2 ether, "invalid max supply");
    }
}
