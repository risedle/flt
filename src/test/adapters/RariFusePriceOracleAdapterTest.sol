// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IVM } from "../IVM.sol";

import { RariFusePriceOracleAdapter } from "../../adapters/RariFusePriceOracleAdapter.sol";
import { gohm, rariFuseGOHMPriceOracle } from "chain/Tokens.sol";
import { usdc, rariFuseUSDCPriceOracle } from "chain/Tokens.sol";
import { IRariFusePriceOracle } from "../../interfaces/IRariFusePriceOracle.sol";
import { IRariFusePriceOracleAdapter } from "../../interfaces/IRariFusePriceOracleAdapter.sol";


/**
 * @title Rari Fuse Price Oracle Adapter Test
 * @author bayu <bayu@risedle.com> <github.com/pyk>
 */
contract RariFusePriceOracleAdapterTest {

    /// ███ Storages █████████████████████████████████████████████████████████

    IVM vm = IVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);


    /// ███ Revert test cases ████████████████████████████████████████████████

    /// @notice Make sure it revert when token oracle is not configured
    function testPriceRevertIfTokenOracleNotConfigured() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Token is not configured, it should be reverted
        vm.expectRevert(
            abi.encodeWithSelector(
                IRariFusePriceOracleAdapter.OracleNotExists.selector,
                gohm
            )
        );
        oracle.price(gohm);
    }

    /// @notice Make sure non-owner cannot configure the oracle
    function testNonOwnerConfigureOracleWillRevert() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Transfer ownership
        address newOwner = vm.addr(1);
        oracle.transferOwnership(newOwner);

        // Configure oracle for token
        vm.expectRevert("Ownable: caller is not the owner");
        oracle.configure(gohm, rariFuseGOHMPriceOracle, 18);
    }

    /// @notice Make sure owner can set the oracle
    function testOwnerCanSetOracle() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for token
        oracle.configure(gohm, rariFuseGOHMPriceOracle, 18);

        // Check the metadata
        (IRariFusePriceOracle rari, uint256 precision) = oracle.oracles(gohm);
        require(address(rari) == rariFuseGOHMPriceOracle, "invalid oracle");
        require(precision == 1e18, "invalid precision");
    }

    /// @notice Make sure it revert when base oracle is not configured
    function testPriceRevertIfBaseOracleNotConfigured() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for tokens
        oracle.configure(usdc, rariFuseUSDCPriceOracle, 6);

        // Base is not configured, it should be reverted
        vm.expectRevert(
            abi.encodeWithSelector(
                IRariFusePriceOracleAdapter.OracleNotExists.selector,
                gohm
            )
        );
        oracle.price(gohm, usdc);
    }

    /// @notice Make sure it revert when base oracle is not configured
    function testTotalValueRevertIfBaseOracleNotConfigured() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for tokens
        oracle.configure(usdc, rariFuseUSDCPriceOracle, 6);

        // Base is not configured, it should be reverted
        vm.expectRevert(
            abi.encodeWithSelector(
                IRariFusePriceOracleAdapter.OracleNotExists.selector,
                gohm
            )
        );
        oracle.totalValue(gohm, usdc, 1e18);
    }

    /// @notice Make sure it revert when quote oracle is not configured
    function testPriceRevertIfQuoteOracleNotConfigured() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for tokens
        oracle.configure(gohm, rariFuseGOHMPriceOracle, 18);

        // Quote is not configured, it should be reverted
        vm.expectRevert(
            abi.encodeWithSelector(
                IRariFusePriceOracleAdapter.OracleNotExists.selector,
                usdc
            )
        );
        oracle.price(gohm, usdc);
    }

    /// @notice Make sure it revert when quote oracle is not configured
    function testTotalValueRevertIfQuoteOracleNotConfigured() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for tokens
        oracle.configure(gohm, rariFuseGOHMPriceOracle, 18);

        // Quote is not configured, it should be reverted
        vm.expectRevert(
            abi.encodeWithSelector(
                IRariFusePriceOracleAdapter.OracleNotExists.selector,
                usdc
            )
        );
        oracle.totalValue(gohm, usdc, 1e18);
    }


    /// ███ Success test cases ███████████████████████████████████████████████

    /// @notice Make sure it returns gOHM/ETH correctly
    function testPriceGOHMETH() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for tokens
        oracle.configure(gohm, rariFuseGOHMPriceOracle, 18);

        // Pin block so the price stay the same
        vm.roll(14723904);
        uint256 price = oracle.price(gohm);
        require(price == 854313772982585805, "gOHM/ETH price invalid");
    }

    /// @notice Make sure it returns gOHM/USDC price correctly
    function testPriceGOHMUSDC() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for tokens
        oracle.configure(gohm, rariFuseGOHMPriceOracle, 18);
        oracle.configure(usdc, rariFuseUSDCPriceOracle, 6);

        // Pin block so the price stay the same
        vm.roll(14723904);
        uint256 price = oracle.price(gohm, usdc);
        require(block.number == 14723904, "invalid block number");
        require(price == 2288149404, "gOHM/USDC price invalid");
    }

    /// @notice Make sure it returns gOHM/USDC value correctly
    function testTotalValueGOHMUSDC() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for tokens
        oracle.configure(gohm, rariFuseGOHMPriceOracle, 18);
        oracle.configure(usdc, rariFuseUSDCPriceOracle, 6);

        // Pin block so the price stay the same
        vm.roll(14723904);
        uint256 price = oracle.price(gohm, usdc);
        uint256 oneTokenValue = oracle.totalValue(gohm, usdc, 1e18);
        uint256 twoTokenValue = oracle.totalValue(gohm, usdc, 2 * 1e18);
        require(price == 2288149404, "gOHM/USDC price invalid");
        require(oneTokenValue == price, "1 gOHM/USDC value invalid");
        require(twoTokenValue == 2 * price, "2 gOHM/USDC value invalid");
    }

    /// @notice Make sure isConfigured returns correct value
    function testIsConfigured() public {
        // Create new oracle
        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();

        // Configure oracle for tokens
        oracle.configure(gohm, rariFuseGOHMPriceOracle, 18);

        // Check configured value
        require(oracle.isConfigured(gohm) == true, "gohm invalid");
        require(oracle.isConfigured(usdc) == false, "usdc invalid");
    }

}
