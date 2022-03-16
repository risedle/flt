// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { IfERC20 } from "../interfaces/IfERC20.sol";
import { HEVM } from "./HEVM.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { GOHM_ADDRESS } from "./Addresses.sol";

// ERC20 addresses on Arbitrum
address constant gohm = 0x8D9bA570D6cb60C7e3e0F31343Efe75AB8E65FB1;
address constant usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
address constant fgohm = 0xd861026A12623aec769fA57D05201193D8844368;
address constant fusdc = 0x156157693BA371c5B126AAeF784D2853EbC8fEFa;

/**
 * @title Rari Fuse User
 * @author bayu (github.com/pyk)
 * @notice RariFuseUser is a smart contract to simulate user interaction on Rari Fuse
 */
contract RariFuseUser {
    using SafeERC20 for IERC20;

    error SupplyFailed();
    error BorrowFailed();

    /**
     * @notice User supply underlying asset to specified fToken
     * @param _underlying The ERC20 compliant token
     * @param _ftoken The fERC20 compliant token
     * @param _amount The amount of _underlying deposited to _ftoken
     */
    function supply(address _underlying, address _ftoken, uint256 _amount) public {
        // Approve
        IERC20(_underlying).safeApprove(_ftoken, _amount);

        // Mint fToken
        if (IfERC20(_ftoken).mint(_amount) != 0) revert SupplyFailed();

        // Reset approval
        IERC20(_underlying).safeApprove(_ftoken, 0);
    }

    /**
     * @notice User borrow the underlying token of fToken
     * @param _ftoken The fERC20 compliant token
     * @param _amount The amount of _underlying borrowed from _ftoken
     */
    function borrow(address _ftoken, uint256 _amount) public {
        if (IfERC20(_ftoken).borrow(_amount) != 0) revert BorrowFailed();
    }

}

/**
 * @title Rari Fuse Test
 * @author bayu (github.com/pyk)
 * @notice Smart contract for testing
 */
contract RariFuseTest is DSTest {
    HEVM internal hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    function testFuse() public {
        // Create new Rari Fuse user
        RariFuseUser user = new RariFuseUser();

        // Setup token balance
        uint256 gohmAmount = 1 ether; // 1 gOHM
        uint256 usdcAmount = 10_000 * 1e6; // 10K USDC
        hevm.setGOHMBalance(address(user), gohmAmount);
        hevm.setUSDCBalance(address(user), usdcAmount);

        // A hack to make sure current block number > accrual block number
        hevm.roll(block.number * 100);

        // Add USDC as supply and GOHM as collateral
        user.supply(usdc, fusdc, usdcAmount);
        user.supply(gohm, fgohm, gohmAmount);

        // Make sure all token is transfered
        uint256 usdcBalance = IERC20(usdc).balanceOf(address(user));
        assertEq(usdcBalance, 0);
        uint256 gohmBalance = IERC20(gohm).balanceOf(address(user));
        assertEq(gohmBalance, 0);

        // Make sure we have fToken
        uint256 fgohmBalance = IERC20(fgohm).balanceOf(address(user));
        assertGt(fgohmBalance, 0);
        uint256 fusdcBalance = IERC20(fusdc).balanceOf(address(user));
        assertGt(fusdcBalance, 0);

        // Borrow USDC from the fUSDC
        uint256 borrowAmount = 500 * 1e6; // 500 USDC
        user.borrow(fusdc, borrowAmount);

        // User should have the underlying token
        usdcBalance = IERC20(usdc).balanceOf(address(user));
        assertEq(usdcBalance, borrowAmount);
    }
}
