// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

/**
 * @title Flash Swapper Interface
 * @author bayu (github.com/pyk)
 * @notice Contract that do flashswap must implement this interface
 */
interface IFlashSwapper {
    function flashCallback(address _borrowToken, uint256 _borrowAmount, address _repayToken, uint256 _repayAmount) external;
}