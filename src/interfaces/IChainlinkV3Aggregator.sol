// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

/**
 * @title Chainlink V3 Aggregator
 * @author bayu (github.com/pyk)
 * @dev docs: https://docs.chain.link/docs/l2-sequencer-flag/
 */
interface IChainlinkV3Aggregator {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
