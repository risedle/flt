// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

/**
 * @title WETH Interface
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
interface IWETH9 is IERC20 {
    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable;

    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256) external;
}
