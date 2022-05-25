// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { RiseToken } from "./RiseToken.sol";
import { IRiseToken } from "./interfaces/IRiseToken.sol";
import { IRiseTokenPeriphery } from "./interfaces/IRiseTokenPeriphery.sol";

/**
 * @title Rise Token Peripheral Contract
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Peripheral smart contract for interacting with Rise Token
 */
contract RiseTokenPeriphery is IRiseTokenPeriphery {

    /// ███ Libraries ████████████████████████████████████████████████████████

    using FixedPointMathLib for uint256;


    /// ███ For Rise Token Creator ███████████████████████████████████████████

    /// @inheritdoc IRiseTokenPeriphery
    function getDefaultParams(
        RiseToken _riseToken,
        uint256 _collateralAmount,
        uint256 _price
    ) public view returns (IRiseToken.InitializeParams memory _params) {
        address collateral = address(_riseToken.collateral());
        address debt = address(_riseToken.debt());

        uint256 cAmount = _collateralAmount.divWadDown(2 ether);
        uint256 cValue = _riseToken.oracleAdapter().totalValue(
            collateral,
            debt,
            _collateralAmount
        );
        uint256 bAmount = _riseToken.oracleAdapter().totalValue(
            collateral,
            debt,
            cAmount
        );
        uint256 nav = cValue - bAmount;
        uint256 shares = nav.divWadDown(_price);

        _params = IRiseToken.InitializeParams({
            borrowAmount: bAmount,
            collateralAmount: _collateralAmount,
            shares: shares,
            leverageRatio: 2 ether,
            nav: _price,
            initializer: address(this),
            ethAmount: 0
        });
    }

    /// @inheritdoc IRiseTokenPeriphery
    function getInitializationParams(
        RiseToken _riseToken,
        uint256 _collateralAmount,
        uint256 _price,
        uint256 _lr
    ) external view returns (IRiseToken.InitializeParams memory _params) {
        address collateral = address(_riseToken.collateral());
        address debt = address(_riseToken.debt());

        _params = getDefaultParams(
            _riseToken,
            _collateralAmount,
            _price
        );

        uint256 cValue = _riseToken.oracleAdapter().totalValue(
            collateral,
            debt,
            _params.collateralAmount
        );
        uint256 nav = cValue - _params.borrowAmount;

        // If target leverage ratio less than 2x, then Leverage down
        if (_lr < 2 ether) {
            uint256 delta = 2 ether - _lr;
            uint256 repayAmount = delta.mulWadDown(nav);
            uint256 collateralSold = _riseToken.oracleAdapter().totalValue(
                debt,
                collateral,
                repayAmount
            );
            _params.borrowAmount -= repayAmount;
            _params.collateralAmount -= collateralSold;
        }

        /// If target leverage ratio larger than 2x, then Leverage up
        if (_lr > 2 ether) {
            uint256 delta = _lr - 2 ether;
            uint256 borrowAmount = delta.mulWadDown(nav);
            uint256 collateralBought = _riseToken.oracleAdapter().totalValue(
                debt,
                collateral,
                borrowAmount
            );
            _params.borrowAmount += borrowAmount;
            _params.collateralAmount += collateralBought;
        }
    }


    /// ███ Rebalancoooor ████████████████████████████████████████████████████

    /// @notice Get max borrow or max repay amount from specified Rise Token
    /// @param _riseToken The target Rise Token
    /// @return _amount The max borrow or max repay amount
    function getMaxBorrowOrRepayAmount(
        RiseToken _riseToken
    ) internal view returns (uint256 _amount) {
        uint256 s = _riseToken.step();
        uint256 nav = _riseToken.value(_riseToken.totalSupply());
        _amount = s.mulWadDown(nav);
    }

    /// @inheritdoc IRiseTokenPeriphery
    function getMaxPush(
        RiseToken _riseToken
    ) external view returns (uint256 _maxAmountIn) {
        // Returns early if leverage ratio is in range
        if (_riseToken.leverageRatio() > _riseToken.minLeverageRatio()) {
            return 0;
        }

        // Otherwise calculate the max push amount
        uint256 maxBorrowAmount = getMaxBorrowOrRepayAmount(_riseToken);

        _maxAmountIn = _riseToken.oracleAdapter().totalValue(
            address(_riseToken.debt()),
            address(_riseToken.collateral()),
            maxBorrowAmount
        );
        _maxAmountIn -= _maxAmountIn.mulWadDown(_riseToken.discount());
    }

    /// @inheritdoc IRiseTokenPeriphery
    function previewPush(
        RiseToken _riseToken,
        uint256 _amountIn
    ) external view returns (uint256 _amountOut) {
        // Revert if leverage ratio in range
        if (_riseToken.leverageRatio() > _riseToken.minLeverageRatio()) {
            revert IRiseToken.NoNeedToRebalance();
        }
        _amountOut = _riseToken.oracleAdapter().totalValue(
            address(_riseToken.collateral()),
            address(_riseToken.debt()),
            _amountIn
        );
        _amountOut += _amountOut.mulWadDown(_riseToken.discount());
    }

    /// @inheritdoc IRiseTokenPeriphery
    function getMaxPull(
        RiseToken _riseToken
    ) external view returns (uint256 _maxAmountOut) {
        // Returns early if leverage ratio is in range
        if (_riseToken.leverageRatio() < _riseToken.maxLeverageRatio()) {
            return 0;
        }

        // Otherwise calculate the max push in and out
        uint256 maxRepayAmount = getMaxBorrowOrRepayAmount(_riseToken);

        _maxAmountOut = _riseToken.oracleAdapter().totalValue(
            address(_riseToken.debt()),
            address(_riseToken.collateral()),
            maxRepayAmount
        );
        _maxAmountOut += _maxAmountOut.mulWadDown(_riseToken.discount());
    }

    /// @inheritdoc IRiseTokenPeriphery
    function previewPull(
        RiseToken _riseToken,
        uint256 _amountOut
    ) external view returns (uint256 _amountIn) {
        // Revert if leverage ratio in range
        if (_riseToken.leverageRatio() < _riseToken.maxLeverageRatio()) {
            revert IRiseToken.NoNeedToRebalance();
        }
        _amountIn = _riseToken.oracleAdapter().totalValue(
            address(_riseToken.collateral()),
            address(_riseToken.debt()),
            _amountOut
        );
        _amountIn -= _amountIn.mulWadDown(_riseToken.discount());
    }


    /// ███ For Rise Token holders ███████████████████████████████████████████

    /// @inheritdoc IRiseTokenPeriphery
    function previewBuy(
        RiseToken _riseToken,
        address _tokenIn,
        uint256 _shares
    ) external view returns (uint256 _amountIn) {
        if (!_riseToken.isInitialized()) revert IRiseToken.TokenNotInitialized();
        if (_shares == 0) return 0;
        uint256 fee = _riseToken.fees().mulWadDown(_shares);
        uint256 newShares = _shares + fee;
        uint256 valueInDebtToken = _riseToken.value(newShares);
        _amountIn = _riseToken.oracleAdapter().totalValue(
            address(_riseToken.debt()),
            _tokenIn,
            valueInDebtToken
        );
    }

    /// @inheritdoc IRiseTokenPeriphery
    function previewSell(
        RiseToken _riseToken,
        address _tokenOut,
        uint256 _shares
    ) external view returns (uint256 _amountOut) {
        if (!_riseToken.isInitialized()) revert IRiseToken.TokenNotInitialized();
        if (_shares == 0) return 0;
        uint256 fee = _riseToken.fees().mulWadDown(_shares);
        uint256 newShares = _shares - fee;
        uint256 valueInDebtToken = _riseToken.value(newShares);
        _amountOut = _riseToken.oracleAdapter().totalValue(
            address(_riseToken.debt()),
            _tokenOut,
            valueInDebtToken
        );
    }
}
