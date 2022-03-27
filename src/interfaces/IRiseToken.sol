// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

/**
 * @title Rise Token Interface
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
interface IRiseToken {
    function factory() external returns (address);
    function uniswapAdapter() external returns (address);
    function oracleAdapter() external returns (address);
    function collateral() external returns (address);
    function debt() external returns (address);
    function fCollateral() external returns (address);
    function fDebt() external returns (address);
    function owner() external returns (address);
}
