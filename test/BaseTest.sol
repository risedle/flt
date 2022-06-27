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
        uint256 totalCollateral;
        uint256 initialPriceInETH;

        // Fuse params
        uint256 debtSupplyAmount;
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


    /// ███ Initialize  ██████████████████████████████████████████████████████

    /// @notice Make sure the transaction revert if non-owner execute
    function _testInitializeRevertIfNonOwnerExecute(Data memory _data) internal {
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
        RiseToken riseToken = deploy(_data);
        uint256 lr = 2 ether;
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            _data,
            lr
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
            lr,
            _data.totalCollateral,
            da,
            shares
        );
    }

    /// @notice Make sure the transaction revert if required amount is not
    //          transfered
    function _testInitializeRevertIfNoTransfer(Data memory _data) internal {
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
        RiseToken riseToken = deploy(_data);
        uint256 lr = 2 ether;
        (uint256 da, , uint256 shares) = getInitializationParams(
            _data,
            lr
        );

        // Initialize without transfer; this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.InvalidBalance.selector
            )
        );
        riseToken.initialize(
            lr,
            _data.totalCollateral,
            da,
            shares
        );
    }

    /// @notice Make sure pancakeCall only pair can call
    function _testPancakeCallRevertIfCallerIsNotPair(Data memory _data) internal {
        // Deploy Rise Token
        RiseToken riseToken = deploy(_data);

        // Call the pancake call
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.Unauthorized.selector
            )
        );
        riseToken.pancakeCall(vm.addr(1), 1 ether, 1 ether, bytes("data"));
    }

    /// @notice Make sure uniswapV2Pair only pair can call
    function _testUniswapV2CallRevertIfCallerIsNotPair(Data memory _data) internal {
        // Deploy Rise Token
        RiseToken riseToken = deploy(_data);

        // Call the Uniswap V2 call
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.Unauthorized.selector
            )
        );
        riseToken.uniswapV2Call(vm.addr(1), 1 ether, 1 ether, bytes("data"));
    }

    /// @notice Make sure 2x have correct states
    function _testInitializeWithLeverageRatio2x(Data memory _data) internal {
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
        RiseToken riseToken = deploy(_data);
        uint256 lr = 2 ether;
        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
            _data,
            lr
        );

        // Transfer `send` amount to riseToken
        setBalance(
            address(_data.debt),
            _data.debtSlot,
            address(this),
            send
        );
        _data.debt.transfer(address(riseToken), send);
        riseToken.initialize(lr, _data.totalCollateral, da, shares);

        // Check the parameters
        assertTrue(riseToken.isInitialized(), "invalid status");

        // Check total collateral
        assertGt(
            riseToken.totalCollateral(),
            _data.totalCollateral-2,
            "total collateral too low"
        );
        assertLt(
            riseToken.totalCollateral(),
            _data.totalCollateral+2,
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
        uint256 percentage = 0.01 ether; // 1%
        uint256 tolerance = percentage.mulWadDown(_data.initialPriceInETH);
        assertGt(
            price,
            _data.initialPriceInETH - tolerance,
            "price too low"
        );
        assertLt(
            price,
            _data.initialPriceInETH + tolerance,
            "price too high"
        );

        // Check leverage ratio
        uint256 currentLR = riseToken.leverageRatio();
        require(currentLR > lr - 0.0001 ether, "lr too low");
        require(currentLR < lr + 0.0001 ether, "lr too high");
    }


}
