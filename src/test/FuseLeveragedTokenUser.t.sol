// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { FuseLeveragedToken } from "../FuseLeveragedToken.sol";
import { HEVM } from "./HEVM.sol";
import { gohm, usdc, fgohm, fusdc, sushiRouter } from "./Arbitrum.sol";
import { UniswapV2Adapter } from "../uniswap/UniswapV2Adapter.sol";
import { GOHMUSDCOracle } from "../oracles/GOHMUSDCOracle.sol";
import { IfERC20 } from "../interfaces/IfERC20.sol";

/**
 * @title FLT User
 * @author bayu (github.com/pyk)
 * @notice Mock contract to simulate user interaction
 */
contract User {
    FuseLeveragedToken private flt;

    constructor(FuseLeveragedToken _flt) {
        flt = _flt;
    }

    /// @notice Simulate user's mint
    function mint(uint256 _shares) external returns (uint256 _collateral) {
        IERC20(gohm).approve(address(flt), type(uint256).max);
        _collateral = flt.mint(_shares, address(this));
        IERC20(gohm).approve(address(flt), 0);
    }

    /// @notice Simulate user's mint with custom recipient
    function mint(uint256 _shares, address _recipient) external returns (uint256 _collateral) {
        IERC20(gohm).approve(address(flt), type(uint256).max);
        _collateral = flt.mint(_shares, _recipient);
        IERC20(gohm).approve(address(flt), 0);
    }

}

/**
 * @title Fuse Leveraged Token User Test
 * @author bayu (github.com/pyk)
 * @notice Make sure all user interactions are working as expected
 */
contract FuseLeveragedTokenUserTest is DSTest {
    HEVM private hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    /// @notice Make sure the default storage is correctly set
    function testDefaultStorage() public {
        address dummy = hevm.addr(100);
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", dummy, dummy, fgohm, fusdc);

        assertEq(flt.name(), "gOHM 2x Long");
        assertEq(flt.symbol(), "gOHMRISE");
        assertEq(flt.decimals(), 18);
        assertEq(flt.collateral(), gohm);
        assertEq(flt.debt(), usdc);
        assertEq(flt.fCollateral(), fgohm);
        assertEq(flt.fDebt(), fusdc);
        assertEq(flt.uniswapAdapter(), dummy);
        assertEq(flt.oracle(), dummy);
        assertTrue(!flt.isBootstrapped());
        assertEq(flt.maxMint(), type(uint256).max);
        assertEq(flt.fees(), 0.001 ether);
    }

    /// @notice Make sure the read-only function is correctly set
    function testDefaultReadOnly() public {
        address dummy = hevm.addr(100);
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", dummy, dummy, fgohm, fusdc);

        assertEq(flt.totalCollateral(), 0);
        assertEq(flt.totalDebt(), 0);
        assertEq(flt.collateralPerShares(), 0);
        assertEq(flt.collateralValuePerShares(), 0);
        assertEq(flt.debtPerShares(), 0);
        assertEq(flt.nav(), 0);
        assertEq(flt.leverageRatio(), 0);
    }

    /// @notice Make sure user cannot mint when FLT is not bootstrapped
    function testFailUserCannotMintIfFLTIsNotBoostrapped() public {
        // Create new FLT
        address dummy = hevm.addr(100);
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", dummy, dummy, fgohm, fusdc);

        // Create new User
        User user = new User(flt);

        // FlT is not bootstrapped but the user trying to mint
        user.mint(1 ether); // This should be reverted
    }

    /// @notice Utility function to deploy and bootstrap FLT
    function bootstrap() internal returns (FuseLeveragedToken) {
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
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", address(adapter), address(oracle), fgohm, fusdc);

        // Top up gOHM balance to this contract
        uint256 collateralAmount = 1 ether;
        hevm.setGOHMBalance(address(this), collateralAmount);

        // Approve the contract to spend gOHM
        IERC20(gohm).approve(address(flt), collateralAmount);

        // Bootstrap the FLT
        uint256 nav = 333 * 1e6; // 333 USDC
        flt.bootstrap(collateralAmount, nav);
        return flt;
    }

    /// @notice Make sure user cannot mint more than maxMint
    function testFailUserCannotMintMoreThanMaxMint() public {
        // Create new FLT
        FuseLeveragedToken flt = bootstrap();

        // Set the max mint
        flt.setMaxMint(2 ether);

        // Create new User
        User user = new User(flt);

        // User trying to mint more than max mint
        user.mint(5 ether); // This should be reverted
    }

    /// @notice Make sure mint is correct
    function testUserCanMint() public {
        // Create new FLT
        FuseLeveragedToken flt = bootstrap();

        // Previous collateral & debt per shares
        uint256 prevCPS = flt.collateralPerShares();
        uint256 prevDPS = flt.debtPerShares();
        uint256 nav = flt.nav();
        uint256 tc = flt.totalCollateral();
        uint256 td = flt.totalDebt();

        // Create new user
        User user = new User(flt);

        // Top up user balance
        hevm.setGOHMBalance(address(user), 1 ether); // 1 gOHM

        // Get preview mint amount
        uint256 shares = 1 ether;
        uint256 previewMintAmount = flt.previewMint(shares);

        // User mint
        uint256 collateralAmount = user.mint(shares);

        // Check preview mint
        assertEq(previewMintAmount, collateralAmount, "check preview");

        // Make sure user token is transfered to the user
        assertEq(IERC20(flt).balanceOf(address(user)), shares, "check user balance");

        // Make sure fee is deducted
        assertEq(IERC20(flt).balanceOf(address(flt)), 0.001 ether, "check collected fees");

        // Make sure FLT debit the correct collateral amount
        assertEq(IERC20(gohm).balanceOf(address(user)), 1 ether - collateralAmount, "check debited collateral");

        // Make sure total collateral and total debt are not changed
        assertEq(flt.collateralPerShares(), prevCPS, "check cps");
        assertEq(flt.debtPerShares(), prevDPS, "check dps");

        // Make sure NAV not changed
        assertEq(flt.nav(), nav, "check nav");
        assertGt(flt.totalCollateral(), tc, "check total collateral");
        assertGt(flt.totalDebt(), td, "check total debt");
    }

    /// @notice Make sure previewMint is return the same thing in one block
    function testPreviewMint() public {
        // Create new FLT
        FuseLeveragedToken flt = bootstrap();

        assertEq(flt.previewMint(1 ether), flt.previewMint(1 ether));
    }

    /// @notice Make sure user can mint with custom recipient
    function testUserCanMintToCustomRecipient() public {
        // Create new FLT
        FuseLeveragedToken flt = bootstrap();

        // Create new user
        User user = new User(flt);

        // Top up user balance
        hevm.setGOHMBalance(address(user), 1 ether); // 1 gOHM

        // Get preview mint amount
        uint256 shares = 1 ether;

        // User mint
        address recipient = hevm.addr(1);
        user.mint(shares, recipient);

        // Make sure user token is transfered to the user
        assertEq(IERC20(flt).balanceOf(recipient), shares, "check user balance");
    }

    /// @notice Make sure previewRedeem is return the same thing in one block
    function testPreviewRedeem() public {
        // Create new FLT
        FuseLeveragedToken flt = bootstrap();

        assertEq(flt.previewRedeem(1 ether), flt.previewRedeem(1 ether));
    }

}
