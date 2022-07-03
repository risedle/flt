// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { IFLT } from "./interfaces/IFLT.sol";
import { IFLTRouter } from "./interfaces/IFLTRouter.sol";
import { FLTFactory } from "./FLTFactory.sol";
import { FLTSinglePair } from "./FLTSinglePair.sol";

/**
 * @title FLTRouter
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice User-friendly contract to swap FLT token
 */
contract FLTRouter is IFLTRouter {

    /// ███ Libraries ████████████████████████████████████████████████████████

    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;


    /// ███ Storages █████████████████████████████████████████████████████████

    FLTFactory public immutable factory;


    /// ███ Constructor ██████████████████████████████████████████████████████

    constructor(FLTFactory _factory) {
        factory = _factory;
    }


    /// ███ Internals ████████████████████████████████████████████████████████

    function getAmountInViaDebt(
        FLTSinglePair _token,
        uint256 _shares
    ) internal view returns (uint256 _amountIn) {
        if (_shares == 0) return 0;
        (uint256 ca, uint256 da) = _token.sharesToUnderlying(_shares);
        address[] memory path = new address[](2);
        path[0] = address(_token.debt());
        path[1] = address(_token.collateral());
        uint256 repayAmount = _token.router().getAmountsIn(ca, path)[0];
        _amountIn = repayAmount - da;
        uint256 feeAmount = _token.fees().mulWadDown(_amountIn);
        _amountIn = _amountIn + feeAmount;
    }

    function getAmountInViaCollateral(
        FLTSinglePair _token,
        uint256 _shares
    ) internal view returns (uint256 _amountIn) {
        if (_shares == 0) return 0;
        (uint256 ca, uint256 da) = _token.sharesToUnderlying(_shares);
        address[] memory path = new address[](2);
        path[0] = address(_token.debt());
        path[1] = address(_token.collateral());
        uint256 borrowAmount = _token.router().getAmountsOut(da, path)[1];
        _amountIn = ca - borrowAmount;
        uint256 feeAmount = _token.fees().mulWadDown(_amountIn);
        _amountIn = _amountIn + feeAmount;
    }

    function getAmountOutViaDebt(
        FLTSinglePair _token,
        uint256 _shares
    ) internal view returns (uint256 _amountOut) {
        if (_shares == 0) return 0;
        (uint256 ca, uint256 da) = _token.sharesToUnderlying(_shares);
        address[] memory path = new address[](2);
        path[0] = address(_token.collateral());
        path[1] = address(_token.debt());
        uint256 borrowAmount = _token.router().getAmountsOut(ca, path)[1];
        _amountOut = borrowAmount - da;
    }

    function getAmountOutViaCollateral(
        FLTSinglePair _token,
        uint256 _shares
    ) internal view returns (uint256 _amountOut) {
        if (_shares == 0) return 0;
        (uint256 ca, uint256 da) = _token.sharesToUnderlying(_shares);
        address[] memory path = new address[](2);
        path[0] = address(_token.collateral());
        path[1] = address(_token.debt());
        uint256 repayAmount = _token.router().getAmountsIn(da, path)[0];
        _amountOut = ca - repayAmount;
    }


    /// ███ Read-only ████████████████████████████████████████████████████████

    /// @inheritdoc IFLTRouter
    function getAmountIn(
        address _flt,
        address _tokenIn,
        uint256 _amountOut
    ) external view returns (uint256 _amountIn) {
        if (!factory.isValid(_flt)) revert InvalidFLT();
        FLTSinglePair flt = FLTSinglePair(_flt);
        if (_tokenIn == address(flt.debt())) {
            return getAmountInViaDebt(flt, _amountOut);
        } else if (_tokenIn == address(flt.collateral())) {
            return getAmountInViaCollateral(flt, _amountOut);
        } else revert InvalidTokenIn();
    }

    /// @notice Get amount out given amount of rise token
    function getAmountOut(
        address _token,
        uint256 _shares,
        address _tokenOut
    ) external view returns (uint256 _amountOut) {
        FLTSinglePair _flt = FLTSinglePair(_token);

        if (_tokenOut == address(_flt.debt())) {
            return getAmountOutViaDebt(_flt, _shares);
        }

        if (_tokenOut == address(_flt.collateral())) {
            return getAmountOutViaCollateral(_flt, _shares);
        }

        revert("invalid tokenOut");
    }


    /// ███ Swaps ████████████████████████████████████████████████████████████

    /// @inheritdoc IFLTRouter
    function swapTokensForExactFLT(
        address _tokenIn,
        uint256 _maxAmountIn,
        address _flt,
        uint256 _amountOut
    ) external {
        if (!factory.isValid(_flt)) revert InvalidFLT();
        IFLT flt = IFLT(_flt);
        if (_tokenIn == address(flt.debt())) {
            ERC20(_tokenIn).safeTransferFrom(
                msg.sender,
                _flt,
                _maxAmountIn
            );
            flt.mintd(_amountOut, msg.sender, msg.sender);
        } else if (_tokenIn == address(flt.collateral())) {
            ERC20(_tokenIn).safeTransferFrom(
                msg.sender,
                _flt,
                _maxAmountIn
            );
            flt.mintc(_amountOut, msg.sender, msg.sender);
        } else revert InvalidTokenIn();
    }


}
