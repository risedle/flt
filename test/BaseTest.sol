// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { IFLT } from "../src/interfaces/IFLT.sol";
import { FLTFactory } from "../src/FLTFactory.sol";
import { FLTSinglePair } from "../src/FLTSinglePair.sol";

abstract contract BaseTest is Test {

    /// ███ Libraries ████████████████████████████████████████████████████████

    using FixedPointMathLib for uint256;


    /// ███ Test data ████████████████████████████████████████████████████████

    // Test data to be defined in child contract
    struct Data {
        string  name;
        string  symbol;
        bytes   deploymentData;
        address implementation;

        // Deployment
        FLTFactory factory;

        // Params
        uint256 collateralSlot;
        uint256 debtSlot;
        uint256 totalCollateral;
        uint256 initialPriceInETH;

        // Fuse params
        uint256 debtSupplyAmount;
    }


    /// ███ Abstract  ████████████████████████████████████████████████████████

    function getData() internal virtual returns (Data memory _data);
    function getInitializationParams(
        address _token,
        uint256 _totalCollateral,
        uint256 _lr,
        uint256 _initialPriceInETH
    ) internal virtual view returns (
        uint256 _totalDebt,
        uint256 _amountSend,
        uint256 _shares
    );
    function getAmountIn(
        address _token,
        uint256 _shares,
        address _tokenIn
    ) internal virtual view returns (uint256 _amountIn);
    function getAmountOut(
        address _token,
        uint256 _shares,
        address _tokenOut
    ) internal virtual view returns (uint256 _amountOut);

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

    /// @notice Deploy new FLT
    function deploy(Data memory _data)
        internal
        returns (IFLT _flt)
    {
        // Deploy the FLT
        _flt = _data.factory.create(
            _data.name,
            _data.symbol,
            _data.deploymentData,
            _data.implementation
        );

        assertEq(ERC20(address(_flt)).name(), _data.name);
        assertEq(ERC20(address(_flt)).symbol(), _data.symbol);
        assertEq(ERC20(address(_flt)).decimals(), 18);
    }

    /// @notice Deploy and initialize FLT
    function deployAndInitialize(
        Data memory _data,
        uint256 _lr
    ) internal returns (IFLT _flt) {
        // Deploy FLT
        _flt = deploy(_data);

        // Add supply to Risedle Pool
        setBalance(
            address(_flt.debt()),
            _data.debtSlot,
            address(this),
            _data.debtSupplyAmount
        );
        _flt.debt().approve(
            address(_flt.fDebt()),
            _data.debtSupplyAmount
        );
        _flt.fDebt().mint(_data.debtSupplyAmount);


        // Initialize Rise Token
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            address(_flt),
            _data.totalCollateral,
            _lr,
            _data.initialPriceInETH
        );

        // Transfer `send` amount to _riseToken
        setBalance(
            address(_flt.debt()),
            _data.debtSlot,
            address(this),
            send
        );
        _flt.debt().transfer(address(_flt), send);
        _flt.initialize(_data.totalCollateral, da, shares);
    }
}
