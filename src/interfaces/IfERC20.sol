// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

/**
 * @title Rari Fuse ERC20 Interface
 * @author bayu (github.com/pyk)
 * @dev docs: https://docs.rari.capital/fuse/#ftoken-s
 */
interface IfERC20 {
    function mint(uint256 mintAmount) external returns (uint256);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function redeemUnderlying(uint redeemAmount) external returns (uint256);
    function borrow(uint256 borrowAmount) external returns (uint256);
    function repayBorrow(uint256 repayAmount) external returns (uint256);
    function accrualBlockNumber() external returns (uint256);
    function borrowBalanceCurrent(address account) external returns (uint256);
    function comptroller() external returns (address);
    function underlying() external returns (address);
    function balanceOfUnderlying(address account) external returns (uint256);
    function totalBorrowsCurrent() external returns (uint256);
}
