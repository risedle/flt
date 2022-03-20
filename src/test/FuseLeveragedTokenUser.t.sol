// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { FuseLeveragedToken } from "../FuseLeveragedToken.sol";
import { HEVM } from "./HEVM.sol";
import { gohm, usdc } from "./Arbitrum.sol";

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

    /// @notice Simulate user's deposit
    function deposit(uint256 _amount) external returns (uint256 _shares) {
        _shares = flt.deposit(_amount, address(this));
    }

    /// @notice Simulate user's deposit with custom recipient
    function deposit(uint256 _amount, address _recipient) external returns (uint256 _shares) {
        _shares = flt.deposit(_amount, _recipient);
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

    function testPublicProperties() public {
        address uniswapAdapter = hevm.addr(100);
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", gohm, usdc, uniswapAdapter, 333 * 1e6);

        // Test public properties
        assertEq(flt.name(), "gOHM 2x Long");
        assertEq(flt.symbol(), "gOHMRISE");
        assertEq(flt.collateral(), gohm);
    }

    /// @notice Make sure the maxDeposit is working as expected
    function testFailUserCannotDepositMoreThanMaxDeposit() public {
        // Create new FLT
        address uniswapAdapter = hevm.addr(100);
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", gohm, usdc, uniswapAdapter, 333 * 1e6);

        // Set max deposit to 0.5 gOHM
        flt.setMaxDeposit(0.5 ether);

        // Create new User
        User user = new User(flt);

        // Top up user balance
        uint256 depositAmount = 1 ether; // 1 gOHM
        hevm.setGOHMBalance(address(this), depositAmount);

        // User trying to deposit more than the max deposit
        user.deposit(depositAmount); // This should be reverted
    }

    /// @notice Make sure when deposit 0, it will returns early
    function testUserDepositZeroCollateral() public {
        // Create new FLT
        address uniswapAdapter = hevm.addr(100);
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", gohm, usdc, uniswapAdapter, 333 * 1e6);

        // Create new User
        User user = new User(flt);

        // User deposit zero collateral, it should return zero
        assertEq(user.deposit(0 ether), 0 ether);
    }

    /// @notice Make sure user cannot use dead address as recipient
    function testFailUserCannotUseDeadAddressAsRecipient() public {
        // Create new FLT
        address uniswapAdapter = hevm.addr(100);
        FuseLeveragedToken flt = new FuseLeveragedToken("gOHM 2x Long", "gOHMRISE", gohm, usdc, uniswapAdapter, 333 * 1e6);

        // Create new User
        User user = new User(flt);

        // User deposit and set recipient as dead address; this should be reverted
        user.deposit(1 ether, address(0));
    }


}
