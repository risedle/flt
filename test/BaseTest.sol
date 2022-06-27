// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { RiseToken } from "../src/RiseToken.sol";
import { RiseTokenFactory } from "../src/RiseTokenFactory.sol";
import { IUniswapV2Pair } from "../src/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Router02 } from "../src/interfaces/IUniswapV2Router02.sol";
import { RariFusePriceOracleAdapter } from "../src/adapters/RariFusePriceOracleAdapter.sol";
import { IfERC20 } from "../src/interfaces/IfERC20.sol";

contract BaseTest is Test {
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
        uint256 debtSlot;
        uint256 leverageRatio;
        uint256 totalCollateral;
        uint256 initialPriceInETH;
    }


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
        Data memory _data
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
        _totalDebt = (tcv.mulWadDown(_data.leverageRatio) - tcv).divWadDown(_data.leverageRatio);
        _amountSend = amountIn - _totalDebt;
        uint256 amountSendValue = _data.oracle.totalValue(
            address(_data.debt),
            address(0),
            _amountSend
        );
        _shares = amountSendValue.divWadDown(_data.initialPriceInETH);
    }


    /// ███ Initialize  ██████████████████████████████████████████████████████

    /// @notice Make sure the transaction revert if non-owner execute
    function _testInitializeRevertIfNonOwnerExecute(
        Data memory _data,
        uint256 _supplyAmount
    ) internal {
        // Add supply to Risedle Pool
        setBalance(
            address(_data.debt),
            _data.debtSlot,
            address(this),
            _supplyAmount
        );
        _data.debt.approve(address(_data.fDebt), _supplyAmount);
        _data.fDebt.mint(_supplyAmount);

        // Deploy Rise Token
        RiseToken riseToken = deploy(_data);

        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            _data
        );

        // Transfer `send` amount to riseToken
        setBalance(
            address(_data.debt),
            _data.debtSlot,
            address(this),
            send
        );
        _data.debt.transfer(address(riseToken), send);

        // Transfer ownership
        address newOwner = vm.addr(2);
        riseToken.transferOwnership(newOwner);

        // Initialize as non owner, this should revert
        vm.expectRevert("Ownable: caller is not the owner");
        riseToken.initialize(
            _data.leverageRatio,
            _data.totalCollateral,
            da,
            shares
        );
    }


}
