// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

/**
 * @title Rari Fuse Comptroller Interface
 * @author bayu (github.com/pyk)
 * @dev docs: https://docs.rari.capital/fuse/#comptroller
 */
interface IFuseComptroller {
    function getAccountLiquidity(address account) external returns (uint256 error, uint256 liquidity, uint256 shortfall);
    function enterMarkets(address[] calldata fTokens) external returns (uint256[] memory);
}
