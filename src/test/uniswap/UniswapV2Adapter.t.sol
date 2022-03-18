// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { UniswapV2Adapter } from "../../uniswap/UniswapV2Adapter.sol";
import { Flasher } from "./Flasher.sol";
import { gohm, usdc } from "../Arbitrum.sol";
import { HEVM } from "../HEVM.sol";

// Sushi Router on Arbitrum Mainnet
address constant sushiRouter = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;

/**
 * @title Uniswap V2 Adapter Test
 * @author bayu (github.com/pyk)
 * @notice Unit testing for UniswapV2Adapter implementation
 */
contract UniswapV2AdapterTest is DSTest {
    HEVM private hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    /// @notice Flasher cannot flash swap with zero amount
    function testFailFlasherCannotFlashZeroAmountBorrowToken() public {
        // Create new adapter
        UniswapV2Adapter adapter = new UniswapV2Adapter(sushiRouter);

        // Create new Flasher
        Flasher flasher = new Flasher(address(adapter));

        // Top up the flasher to repay the borrow
        hevm.setUSDCBalance(address(flasher), 10_000 * 1e6); // 10K USDC

        // Trigger the flash swap; this should be failed
        flasher.trigger(gohm, 0, usdc);
    }

    /// @notice Flasher cannot flash swap with invalid borrow token
    function testFailFlasherCannotFlashSwapWithInvalidBorrowToken() public {
        // Create new adapter
        UniswapV2Adapter adapter = new UniswapV2Adapter(sushiRouter);

        // Create new Flasher
        Flasher flasher = new Flasher(address(adapter));

        // Top up the flasher to repay the borrow
        hevm.setUSDCBalance(address(flasher), 10_000 * 1e6); // 10K USDC

        // Trigger the flash swap; this should be failed
        address randomToken = hevm.addr(1);
        flasher.trigger(randomToken, 1 ether, usdc);
    }

    /// @notice Flasher cannot flash swap with invalid repay token
    function testFailFlasherCannotFlashSwapWithInvalidRepayToken() public {
        // Create new adapter
        UniswapV2Adapter adapter = new UniswapV2Adapter(sushiRouter);

        // Create new Flasher
        Flasher flasher = new Flasher(address(adapter));

        // Top up the flasher to repay the borrow
        hevm.setUSDCBalance(address(flasher), 10_000 * 1e6); // 10K USDC

        // Trigger the flash swap; this should be failed
        address randomToken = hevm.addr(1);
        flasher.trigger(gohm, 1 ether, randomToken);
    }
}
