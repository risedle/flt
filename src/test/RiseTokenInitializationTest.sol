// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IVM } from "./IVM.sol";
import { VMUtils } from "./VMUtils.sol";

import { RiseTokenUtils } from "./RiseTokenUtils.sol";
import { RiseTokenPeriphery } from "../RiseTokenPeriphery.sol";
import { fusdc, fwbtc } from "chain/Tokens.sol";

import { RiseTokenFactory } from "../RiseTokenFactory.sol";
import { RiseToken } from "../RiseToken.sol";
import { IRiseToken } from "../interfaces/IRiseToken.sol";

/**
 * @title Rise Token Initialization Test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract RiseTokenInitializationTest {

    /// ███ Storages █████████████████████████████████████████████████████████

    IVM private immutable vm = IVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    VMUtils             private utils;
    RiseTokenUtils      private riseTokenUtils;
    RiseTokenPeriphery  private periphery;


    /// ███ Test Setup ███████████████████████████████████████████████████████

    function setUp() public {
        // Create utils
        utils = new VMUtils(vm);

        // Create RiseToken utils contract
        riseTokenUtils = new RiseTokenUtils();

        // Create Periphery
        periphery = new RiseTokenPeriphery();
    }


    /// ███ initialize ███████████████████████████████████████████████████████

    /// @notice Make sure the transaction revert if non-owner execute
    function testInitializeRevertIfNonOwnerExecute() public {
        // Create factory
        address feeRecipient = vm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new Rise token
        RiseToken wbtcRise = factory.create(
            fwbtc,
            fusdc,
            riseTokenUtils.uniswapAdapter(),
            riseTokenUtils.oracleAdapter()
        );

        // Add supply to the Rari Fuse
        uint256 supplyAmount = 100_000_000 * 1e6; // 100M USDC
        utils.setUSDCBalance(address(this), supplyAmount);
        wbtcRise.debt().approve(address(fusdc), supplyAmount);
        fusdc.mint(supplyAmount);

        // Initialize WBTCRISE
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        uint256 lr = 2 ether; // 2x

        IRiseToken.InitializeParams memory params;
        params = periphery.getInitializationParams(
            wbtcRise,
            collateralAmount,
            price,
            lr
        );

        // Transfer ownership
        address newOwner = vm.addr(2);
        wbtcRise.transferOwnership(newOwner);

        // Initialize as non owner, this should revert
        vm.expectRevert("Ownable: caller is not the owner");
        wbtcRise.initialize{value: 1000 ether}(params);
    }

    /// @notice Make sure the transaction revert if slippage too high
    function testInitializeRevertIfSlippageTooHigh() public {
        // Create factory
        address feeRecipient = vm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new Rise token
        RiseToken wbtcRise = factory.create(
            fwbtc,
            fusdc,
            riseTokenUtils.uniswapAdapter(),
            riseTokenUtils.oracleAdapter()
        );

        // Add supply to the Rari Fuse
        uint256 supplyAmount = 100_000_000 * 1e6; // 100M USDC
        utils.setUSDCBalance(address(this), supplyAmount);
        wbtcRise.debt().approve(address(fusdc), supplyAmount);
        fusdc.mint(supplyAmount);

        // Initialize WBTCRISE
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        uint256 lr = 2 ether; // 2x

        IRiseToken.InitializeParams memory params;
        params = periphery.getInitializationParams(
            wbtcRise,
            collateralAmount,
            price,
            lr
        );

        // Initialize with low ETH amount, this should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.SlippageTooHigh.selector
            )
        );
        wbtcRise.initialize{value: 0.001 ether}(params);
    }

    /// @notice Make sure 2x have correct states
    function testInitializeWithLeverageRatio2x() public {
        // Create and initialize
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        uint256 lr = 2 ether; // 2x
        riseTokenUtils.initializeWBTCRISE{ value: 20 ether }(wbtcRise, lr);

        // Check the parameters
        require(wbtcRise.isInitialized(), "invalid status");

        // Check total collateral
        require(wbtcRise.totalCollateral() == 1e8, "invalid total collateral");

        // Check total debt
        uint256 debt = riseTokenUtils.oracleAdapter().totalValue(
            address(wbtcRise.collateral()),
            address(wbtcRise.debt()),
            0.5*1e8 // 0.5 WBTC to USDC
        );
        require(wbtcRise.totalDebt() == debt, "invalid total debt");

        // Check total supply
        uint256 totalSupply = wbtcRise.totalSupply();
        uint256 balance = wbtcRise.balanceOf(address(riseTokenUtils));
        require(totalSupply > 0, "invalid total supply");
        require(balance == totalSupply, "invalid balance");

        // Check price
        uint256 price = wbtcRise.price();
        require(price > 400*1e6 - 1e6, "price too low");
        require(price < 400*1e6 + 1e6, "price too high");

        // Check leverage ratio
        uint256 currentLR = wbtcRise.leverageRatio();
        require(currentLR > lr - 0.0001 ether, "lr too low");
        require(currentLR < lr + 0.0001 ether, "lr too high");

        // Make sure ETH is refunded
        uint256 afterBalance = address(riseTokenUtils).balance;
        require(afterBalance > 0, "balance too low");
        require(afterBalance < 20 ether, "balance too high");

    }

    /// @notice Make sure 1.6x have correct states
    function testInitializeWithLeverageRatioLessThan2x() public {
        // Create and initialize
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        uint256 lr = 1.6 ether; // 1.6x
        riseTokenUtils.initializeWBTCRISE{ value: 20 ether }(wbtcRise, lr);

        // Check the parameters
        require(wbtcRise.isInitialized(), "invalid status");

        // Check total collateral
        require(wbtcRise.totalCollateral() < 1e8, "invalid total collateral");

        // Check total debt
        uint256 debt = riseTokenUtils.oracleAdapter().totalValue(
            address(wbtcRise.collateral()),
            address(wbtcRise.debt()),
            0.5*1e8 // 0.5 WBTC to USDC
        );
        require(wbtcRise.totalDebt() < debt, "invalid total debt");

        // Check total supply
        uint256 totalSupply = wbtcRise.totalSupply();
        uint256 balance = wbtcRise.balanceOf(address(riseTokenUtils));
        require(totalSupply > 0, "invalid total supply");
        require(balance == totalSupply, "invalid balance");

        // Check price
        uint256 price = wbtcRise.price();
        require(price > 400*1e6 - 1e6, "price too low");
        require(price < 400*1e6 + 1e6, "price too high");

        // Check leverage ratio
        uint256 currentLR = wbtcRise.leverageRatio();
        require(currentLR > lr - 0.0001 ether, "lr too low");
        require(currentLR < lr + 0.0001 ether, "lr too high");

        // Make sure ETH is refunded
        uint256 afterBalance = address(riseTokenUtils).balance;
        require(afterBalance > 0, "balance too low");
        require(afterBalance < 20 ether, "balance too high");
    }

    /// @notice Make sure 2.5x have correct states
    function testInitializeWithLeverageRatioGreaterThan2x() public {
        // Create and initialize
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        uint256 lr = 2.5 ether; // 2.5x
        riseTokenUtils.initializeWBTCRISE{ value: 20 ether }(wbtcRise, lr);

        // Check the parameters
        require(wbtcRise.isInitialized(), "invalid status");

        // Check total collateral
        require(wbtcRise.totalCollateral() > 1e8, "invalid total collateral");

        // Check total debt
        uint256 debt = riseTokenUtils.oracleAdapter().totalValue(
            address(wbtcRise.collateral()),
            address(wbtcRise.debt()),
            0.5*1e8 // 0.5 WBTC to USDC
        );
        require(wbtcRise.totalDebt() > debt, "invalid total debt");

        // Check total supply
        uint256 totalSupply = wbtcRise.totalSupply();
        uint256 balance = wbtcRise.balanceOf(address(riseTokenUtils));
        require(totalSupply > 0, "invalid total supply");
        require(balance == totalSupply, "invalid balance");

        // Check price
        uint256 price = wbtcRise.price();
        require(price > 400*1e6 - 1e6, "price too low");
        require(price < 400*1e6 + 1e6, "price too high");

        // Check leverage ratio
        uint256 currentLR = wbtcRise.leverageRatio();
        require(currentLR > lr - 0.001 ether, "lr too low");
        require(currentLR < lr + 0.001 ether, "lr too high");

        // Make sure ETH is refunded
        uint256 afterBalance = address(riseTokenUtils).balance;
        require(afterBalance > 0, "balance too low");
        require(afterBalance < 20 ether, "balance too high");
    }
}
