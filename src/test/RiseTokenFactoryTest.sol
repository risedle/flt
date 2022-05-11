// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IVM } from "./IVM.sol";

import { RiseTokenFactory } from "../RiseTokenFactory.sol";
import { IRiseTokenFactory } from "../interfaces/IRiseTokenFactory.sol";
import { UniswapAdapter } from "../adapters/UniswapAdapter.sol";
import { IUniswapAdapter } from "../interfaces/IUniswapAdapter.sol";
import { RariFusePriceOracleAdapter } from "../adapters/RariFusePriceOracleAdapter.sol";

import { weth, wbtc, usdc } from "chain/Tokens.sol";
import { fusdc, fwbtc } from "chain/Tokens.sol";
import { RiseToken } from "../RiseToken.sol";

/**
 * @title Rise Token Factory Test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract RiseTokenFactoryTest {

    /// ███ Storages █████████████████████████████████████████████████████████

    IVM private immutable vm = IVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    /// @notice Test default state
    function testDefaultStorages() public {
        // Create new factory
        address feeRecipient = vm.addr(2);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Check
        require(factory.feeRecipient() == feeRecipient, "invalid fee recipient");
    }


    /// ███ setFeeRecipient ██████████████████████████████████████████████████

    /// @notice Non-owner cannot set fee recipient
    function testSetFeeRecipientAsNonOwnerRevert() public {
        // Create new factory
        address feeRecipient = vm.addr(2);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Transfer ownership
        address newOwner = vm.addr(2);
        factory.transferOwnership(newOwner);

        // Non-owner trying to set the fee recipient; It should be reverted
        address recipient = vm.addr(3);
        vm.expectRevert("Ownable: caller is not the owner");
        factory.setFeeRecipient(recipient);
    }

    /// @notice Owner can set fee recipient
    function testSetFeeRecipientAsOwner() public {
        // Create new factory
        address feeRecipient = vm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Non-owner trying to set the fee recipient; It should be reverted
        address recipient = vm.addr(2);
        factory.setFeeRecipient(recipient);

        // Check
        require(factory.feeRecipient() == recipient, "invalid recipient");
    }


    /// ███ create ███████████████████████████████████████████████████████████

    /// @notice Non-owner cannot create token
    function testCreateAsNonOwnerRevert() public {
        // Create new factory
        address feeRecipient = vm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Transfer ownership
        address newOwner = vm.addr(2);
        factory.transferOwnership(newOwner);

        // Non-owner trying to set the fee recipient; It should be reverted
        vm.expectRevert("Ownable: caller is not the owner");
        factory.create(
            fwbtc,
            fusdc,
            UniswapAdapter(vm.addr(3)),
            RariFusePriceOracleAdapter(vm.addr(4))
        );
    }

    function eq(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    /// @notice Owner can set fee recipient
    function testCreateAsOwner() public {
        // Create new factory
        address feeRecipient = vm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new token
        UniswapAdapter uniswapAdapter = new UniswapAdapter(weth);
        RariFusePriceOracleAdapter oracleAdapter = new RariFusePriceOracleAdapter();
        RiseToken riseToken = factory.create(fwbtc, fusdc, uniswapAdapter, oracleAdapter);

        // Check public properties
        string memory name = "WBTC 2x Long Risedle";
        string memory symbol = "WBTCRISE";
        require(eq(riseToken.name(), name), "invalid name");
        require(eq(riseToken.symbol(), symbol), "invalid symbol");
        require(riseToken.decimals() == 18, "invalid decimals");

        require(address(riseToken.factory()) == address(factory), "invalid factory");
        require(address(riseToken.collateral()) == wbtc, "invalid collateral");
        require(address(riseToken.debt()) == usdc, "invalid debt");
        require(address(riseToken.fCollateral()) == address(fwbtc), "invalid fCollateral");
        require(address(riseToken.fDebt()) == address(fusdc), "invalid fDebt");
        require(riseToken.owner() == address(this), "invalid owner");
        require(
            address(riseToken.uniswapAdapter()) == address(uniswapAdapter),
            "invalid uniswap adapter"
        );
        require(
            address(riseToken.oracleAdapter()) == address(oracleAdapter),
            "check oracle adapter"
        );
    }

}
