// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { weth, wbtc, uniswapV3WBTCETHPool, uniswapV3Router } from "chain/Tokens.sol";
import { UniswapAdapter } from "../../uniswap/UniswapAdapter.sol";
import { HEVM } from "../hevm/HEVM.sol";
import { IUniswapV2Pair } from "../../interfaces/IUniswapV2Pair.sol";
import { IUniswapV3Pool } from "../../interfaces/IUniswapV3Pool.sol";

/**
 * @title Uniswap Adapter Test
 * @author bayu (github.com/pyk)
 * @notice Unit testing for Uniswap Adapter
 */
contract UniswapAdapterTest is DSTest {
    HEVM private hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    /// @notice Make sure only owner can set token metadata
    function testFailNonOwnerCannotSetTokenMetadata() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Transfer ownership to new owner
        address newOwner = hevm.addr(1);
        adapter.transferOwnership(newOwner);

        // Non-owner trying to set the token metadata; This should be reverted
        adapter.setMetadata(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);
    }

    /// @notice Make sure owner can set token metadata
    function testOwnerCanSetMetadata() public {
        // Create new Uniswap Adapter
        UniswapAdapter adapter = new UniswapAdapter(weth);

        // Owner set metadata
        adapter.setMetadata(wbtc, 3, uniswapV3WBTCETHPool, uniswapV3Router);

        // Check the value
        (uint8 version, IUniswapV2Pair pair, IUniswapV3Pool pool, address router) = adapter.tokens(wbtc);
        assertEq(version, 3);
        // Pair and pool is set to the same address
        assertEq(address(pair), uniswapV3WBTCETHPool);
        assertEq(address(pool), uniswapV3WBTCETHPool);
        // Router
        assertEq(router, uniswapV3Router);
    }

}