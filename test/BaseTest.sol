// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { RiseToken } from "../src/RiseToken.sol";
import { RiseTokenFactory } from "../src/RiseTokenFactory.sol";
import { IRiseToken } from "../src/interfaces/IRiseToken.sol";
import { IUniswapV2Pair } from "../src/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Router02 } from "../src/interfaces/IUniswapV2Router02.sol";
import { RariFusePriceOracleAdapter } from "../src/adapters/RariFusePriceOracleAdapter.sol";
import { IfERC20 } from "../src/interfaces/IfERC20.sol";

abstract contract BaseTest is Test {

    /// ███ Libraries ████████████████████████████████████████████████████████

    using FixedPointMathLib for uint256;


    /// ███ Test data ████████████████████████████████████████████████████████

    // Test data to be defined in child contract
    struct Data {
        // Factory
        RiseTokenFactory factory;

        // Name and Symbol
        string name;
        string symbol;

        // Underlying collateral and debt
        ERC20 collateral;
        ERC20 debt;

        // Fuse collateral and debt
        IfERC20 fCollateral;
        IfERC20 fDebt;
        RariFusePriceOracleAdapter oracle;

        // Collateral/Debt pair and the router
        IUniswapV2Pair pair;
        IUniswapV2Router02 router;

        // Params
        uint256 collateralSlot;
        uint256 debtSlot;
        uint256 totalCollateral;
        uint256 initialPriceInETH;

        // Fuse params
        uint256 debtSupplyAmount;
    }


    /// ███ Abstract  ████████████████████████████████████████████████████████

    /// @notice Return test data
    function getData() internal virtual returns (Data memory _data);


    /// ███ Utilities ████████████████████████████████████████████████████████

    /// @notice Deploy new Rise Token
    function deploy(
        Data memory _data
    ) internal returns (RiseToken _riseToken) {
        // Create new Rise Token
        _riseToken = new RiseToken(
            _data.name,
            _data.symbol,
            _data.factory,
            _data.fCollateral,
            _data.fDebt,
            _data.oracle,
            _data.pair,
            _data.router
        );
    }

    /// @notice Deploy and initialize rise token
    function deployAndInitialize(
        Data memory _data,
        uint256 _lr
    ) internal returns (RiseToken _riseToken) {
        // Add supply to Risedle Pool
        setBalance(
            address(_data.debt),
            _data.debtSlot,
            address(this),
            _data.debtSupplyAmount
        );
        _data.debt.approve(address(_data.fDebt), _data.debtSupplyAmount);
        _data.fDebt.mint(_data.debtSupplyAmount);

        // Deploy Rise Token
        _riseToken = deploy(_data);

        // Initialize Rise Token
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            _data,
            _lr
        );

        // Transfer `send` amount to _riseToken
        setBalance(address(_data.debt), _data.debtSlot, address(this), send);
        _data.debt.transfer(address(_riseToken), send);
        _riseToken.initialize(_data.totalCollateral, da, shares);
    }

    /// @notice Set balance given a token
    function setBalance(
        address _token,
        uint256 _slot,
        address _to,
        uint256 _amount
    ) internal {
        vm.store(
            _token,
            keccak256(abi.encode(_to, _slot)),
            bytes32(_amount)
        );
    }

    function getInitializationParams(
        Data memory _data,
        uint256 _lr
    ) internal view returns (
        uint256 _totalDebt,
        uint256 _amountSend,
        uint256 _shares
    ) {
        address[] memory path = new address[](2);
        path[0] = address(_data.debt);
        path[1] = address(_data.collateral);
        uint256 amountIn = _data.router.getAmountsIn(
            _data.totalCollateral,
            path
        )[0];
        uint256 tcv = _data.oracle.totalValue(
            address(_data.collateral),
            address(_data.debt),
            _data.totalCollateral
        );
        _totalDebt = (tcv.mulWadDown(_lr) - tcv).divWadDown(_lr);
        _amountSend = amountIn - _totalDebt;
        uint256 amountSendValue = _data.oracle.totalValue(
            address(_data.debt),
            address(0),
            _amountSend
        );
        _shares = amountSendValue.divWadDown(_data.initialPriceInETH);
    }

    /// @notice getAmountIn via debt token
    function getAmountInViaDebt(
        RiseToken _token,
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
        RiseToken _token,
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
        RiseToken _token,
        uint256 _shares,
        address _tokenIn
    ) internal view returns (uint256 _amountIn) {
        if (_tokenIn == address(_token.debt())) {
            return getAmountInViaDebt(_token, _shares);
        }

        if (_tokenIn == address(_token.collateral())) {
            return getAmountInViaCollateral(_token, _shares);
        }

        revert("invalid tokenIn");
    }

    /// @notice Given amount of Rise Token, get the debt output
    function getAmountOutViaDebt(
        RiseToken _token,
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
        RiseToken _token,
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
        RiseToken _token,
        uint256 _shares,
        address _tokenOut
    ) internal view returns (uint256 _amountOut) {
        if (_tokenOut == address(_token.debt())) {
            return getAmountOutViaDebt(_token, _shares);
        }

        if (_tokenOut == address(_token.collateral())) {
            return getAmountOutViaCollateral(_token, _shares);
        }

        revert("invalid tokenOut");
    }

}
