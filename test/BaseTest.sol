// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import { Owned } from "solmate/auth/Owned.sol";

import { IFLT } from "../src/interfaces/IFLT.sol";
import { FLTFactory } from "../src/FLTFactory.sol";

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


    /// ███ Utilities ████████████████████████████████████████████████████████

    /// @notice Deploy new FLT
    function deploy(Data memory _data) internal returns (IFLT _flt) {
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

    /// @notice Get required collateral to push leverage ratio up
    function getLeveragingUpInOut(
        IFLT _token
    ) internal view returns (uint256 _amountIn, uint256 _amountOut) {
        uint256 ts = ERC20(address(_token)).totalSupply();
        uint256 amountOutInETH = _token.step().mulWadDown(
            _token.value(ts)
        );
        _amountOut = _token.oracleAdapter().totalValue(
            address(0),
            address(_token.debt()),
            amountOutInETH
        );
        uint256 expectedAmountIn = _token.oracleAdapter().totalValue(
            address(0),
            address(_token.collateral()),
            amountOutInETH
        );
        uint256 amountInDiscount = _token.discount().mulWadDown(
            expectedAmountIn
        );
        _amountIn = expectedAmountIn - amountInDiscount;
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

    /// @notice Get required debt to push leverage ratio down
    function getLeveragingDownInOut(
        IFLT _token
    ) internal view returns (uint256 _amountIn, uint256 _amountOut) {
        uint256 ts = ERC20(address(_token)).totalSupply();
        uint256 amountOutInETH = _token.step().mulWadDown(_token.value(ts));
        _amountOut = _token.oracleAdapter().totalValue(
            address(0),
            address(_token.collateral()),
            amountOutInETH
        );
        uint256 expectedAmountIn = _token.oracleAdapter().totalValue(
            address(0),
            address(_token.debt()),
            amountOutInETH
        );
        uint256 amountInDiscount = _token.discount().mulWadDown(
            expectedAmountIn
        );
        _amountIn = expectedAmountIn - amountInDiscount;
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
}
