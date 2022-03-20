// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

/**
 * @title Oracle Interface
 * @author bayu (github.com/pyk)
 * @notice Every FLT oracle should implement this interface.
 */
interface IOracle {
    // Get price of the collateral based on the debt asset
    // For example ETH that trade 4000 USDC is returned as 4000 * 1e6 because USDC have 6 decimals
    function getPrice() external view returns (uint256 price);
}
