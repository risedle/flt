// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { FuseLeveragedToken } from "../FuseLeveragedToken.sol";
import { HEVM } from "./HEVM.sol";
import { gohm, fgohm, usdc, fusdc, sushiRouter } from "./Arbitrum.sol";
import { UniswapV2Adapter } from "../uniswap/UniswapV2Adapter.sol";
import { GOHMUSDCOracle } from "../oracles/GOHMUSDCOracle.sol";
import { IfERC20 } from "../interfaces/IfERC20.sol";

/**
 * @title Fuse Leveraged Token Access Control Test
 * @author bayu (github.com/pyk)
 * @notice Make sure the access control works as expected
 */
contract FuseLeveragedTokenAccessControlTest is DSTest {
    HEVM private hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    /// @notice Make sure non-owner cannot set the maxDeposit value
    function testFailNonOwnerCannotSetMaxDeposit() public {
        // Create new FLT; by default the deployer is the owner
        address dummy = hevm.addr(100);
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", gohm, usdc, dummy, dummy, dummy, dummy);

        // Transfer the ownership
        address newOwner = hevm.addr(1);
        flt.transferOwnership(newOwner);

        // Non-owner trying to set the maxDeposit value
        flt.setMaxDeposit(1 ether); // This should be failed
    }

    /// @notice Make sure owner can set the maxDeposit value
    function testOwnerCanSetMaxDeposit() public {
        // Create new FLT; by default the deployer is the owner
        address dummy = hevm.addr(100);
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", gohm, usdc, dummy, dummy, dummy, dummy);

        // Make sure the default value is set
        assertEq(flt.maxDeposit(), type(uint256).max);

        // Owner set the maxDeposit
        uint256 newMaxDeposit = 1 ether;
        flt.setMaxDeposit(newMaxDeposit);

        // Make sure the value is updated
        assertEq(flt.maxDeposit(), newMaxDeposit);
    }

    /// @notice Make sure non-owner cannot call the bootstrap function
    function testFailNonOwnerCannotBootstrapTheFLT() public {
        // Create new FLT; by default the deployer is the owner
        address dummy = hevm.addr(100);
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", gohm, usdc, dummy, dummy, dummy, dummy);

        // Transfer the ownership
        address newOwner = hevm.addr(1);
        flt.transferOwnership(newOwner);

        // Non-owner try to bootstrap the FLT
        flt.bootstrap(2 ether, 333 * 1e6);
    }

    /// @notice Make sure owner can bootstrap the FLT
    function testOwnerCanBootstrapTheFLT() public {
        // A hack to make sure current block number > accrual block number on Rari Fuse
        hevm.roll(block.number * 100);

        // Add supply to the Rari Fuse
        uint256 supplyAmount = 100_000 * 1e6; // 100K USDC
        hevm.setUSDCBalance(address(this), supplyAmount);
        IERC20(usdc).approve(fusdc, supplyAmount);
        IfERC20(fusdc).mint(supplyAmount);

        // Create the Uniswap Adapter
        UniswapV2Adapter adapter = new UniswapV2Adapter(sushiRouter);

        // Create the collateral oracle
        GOHMUSDCOracle oracle = new GOHMUSDCOracle();

        // Create new FLT
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", gohm, usdc, address(adapter), address(oracle), fgohm, fusdc);

        // Top up gOHM balance to this contract
        uint256 collateralAmount = 1 ether;
        hevm.setGOHMBalance(address(this), collateralAmount);

        // Approve the contract to spend gOHM
        IERC20(gohm).approve(address(flt), collateralAmount);

        // Bootstrap the FLT
        uint256 nav = 333 * 1e6; // 333 USDC
        flt.bootstrap(collateralAmount, nav);

        // Make sure the isBootstrap is set to true
        assertTrue(flt.isBootstrapped());

        // Make sure the total collateral is correct
        uint256 totalCollateral = flt.totalCollateral();
        assertEq(totalCollateral, 1.9 ether);
        uint256 balance = IERC20(fgohm).balanceOf(address(flt));
        assertGt(balance, 0);

        // Make sure the total debt is correct
        uint256 price = oracle.getPrice();
        uint256 debt = (0.95 ether * price) / 1 ether;
        assertEq(flt.totalDebt(), debt);
        assertEq(IfERC20(fusdc).borrowBalanceCurrent(address(flt)), debt);

        // Make sure the total shares is correct
        assertEq(flt.totalShares(), (totalCollateral * price * 1 ether) / nav);

        // Make sure the token is minted to this contract
        assertEq(flt.balanceOf(address(this)), flt.totalShares());
    }
}
