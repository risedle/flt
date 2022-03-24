// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { FuseLeveragedToken } from "../FuseLeveragedToken.sol";
import { HEVM } from "./HEVM.sol";
import { gohm, usdc, fgohm, fusdc } from "./Arbitrum.sol";

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
    function mint(uint256 _shares) external {
        flt.mint(_shares, address(this));
    }

    // /// @notice Simulate user's deposit with custom recipient
    // function deposit(uint256 _amount, address _recipient) external returns (uint256 _shares) {
    //     _shares = flt.deposit(_amount, _recipient);
    // }
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

    // /// @notice Make sure when deposit 0, it will returns early
    // function testUserDepositZeroCollateral() public {
    //     // Create new FLT
    //     address dummy = hevm.addr(100);
    //     FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", gohm, usdc, dummy, dummy, dummy);

    //     // Create new User
    //     User user = new User(flt);

    //     // User deposit zero collateral, it should return zero
    //     assertEq(user.deposit(0 ether), 0 ether);
    // }

    // /// @notice Make sure user cannot use dead address as recipient
    // function testFailUserCannotUseDeadAddressAsRecipient() public {
    //     // Create new FLT
    //     address dummy = hevm.addr(100);
    //     FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", gohm, usdc, dummy, dummy, dummy);

    //     // Create new User
    //     User user = new User(flt);

    //     // User deposit and set recipient as dead address; this should be reverted
    //     user.deposit(1 ether, address(0));
    // }


}
