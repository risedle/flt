// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { GOHMUSDCOracle } from "../../oracles/GOHMUSDCOracle.sol";

/**
 * @title gOHM/USDC Oracle Test
 * @author bayu (github.com/pyk)
 * @notice Unit test for GOHMUSDCOracle contract
 */
contract GOHMUSDCOracleTest is DSTest {
    /// @notice Make sure the oracle return the correct price
    function testGOHMUSDCPrice() public {
        // Create new gOHM/USDC oracle
        GOHMUSDCOracle oracle = new GOHMUSDCOracle();

        // Get the gOHM price
        uint256 gohmPrice = oracle.getPrice();

        // Make sure the value is in range 1K USDC and 5K USDC
        assertGt(gohmPrice, 1_000 * 1e6);
        assertLt(gohmPrice, 5_000 * 1e6);
    }
}
