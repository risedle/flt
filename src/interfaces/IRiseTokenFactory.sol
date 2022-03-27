// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

/**
 * @title Rise Token Factory Interface
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
interface IRiseTokenFactory {
    function uniswapAdapter() external returns (address);
    function oracleAdapter() external returns (address);
    function feeRecipient() external returns (address);
    function owner() external returns (address);
}
