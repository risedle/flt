// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

/**
 * @title Chainlink L2 Flag
 * @author bayu (github.com/pyk)
 * @dev docs: https://docs.chain.link/docs/l2-sequencer-flag/
 */
interface IChainlinkL2Flag {
    function getFlag(address) external view returns (bool);
}