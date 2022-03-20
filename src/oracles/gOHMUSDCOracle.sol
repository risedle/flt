// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { IChainlinkV3Aggregator } from "../interfaces/IChainlinkV3Aggregator.sol";
import { IChainlinkL2Flag } from "../interfaces/IChainlinkL2Flag.sol";

/**
 * @title gOHM/USDC Oracle
 * @author bayu (github.com/pyk)
 * @notice This oracle returns the latest price of gOHM in term of USDC
 */
contract gOHMUSDCOracle {
    /// ███ Storages ███████████████████████████████████████████████████████████

    // Chainlink feed addreses on arbitrum
    address public immutable ohmIndexFeed = 0x48C4721354A3B29D80EF03C65E6644A37338a0B1;
    address public immutable ohmFeed = 0x761aaeBf021F19F198D325D7979965D0c7C9e53b;
    address public immutable usdcFeed = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;
    address public immutable flag = 0x3C14e07Edd0dC67442FA96f1Ec6999c57E810a83;
    address private offlineFlag = address(bytes20(bytes32(uint256(keccak256("chainlink.flags.arbitrum-seq-offline")) - 1)));


    /// ███ Errors █████████████████████████████████████████████████████████████

    /// @notice Error is raised when Chainlink sequencer goes offline
    error SequencerOffline();


    /// ███ Internal functions █████████████████████████████████████████████████

    /**
     * @notice Gets the current index of OHM
     * @return index The current index of OHM (1e9 precision)
     */
    function getOHMIndex() public view returns (uint256 index) {
        (, int256 _index, , , ) = IChainlinkV3Aggregator(ohmIndexFeed).latestRoundData();
        index = uint256(_index);
    }

    /**
     * @notice Gets the price of chainlink feed in USD
     * @param _feed The contract address of the chainlink feed (e.g. ETH/USD or USDC/USD)
     * @return price The USD price (1e9 precision)
     */
    function getPriceInUSD(address _feed) internal view returns (uint256 price) {
        // Get latest price
        (, int256 _price, , , ) = IChainlinkV3Aggregator(_feed).latestRoundData();

        // Get feed decimals representation
        uint8 feedDecimals = IChainlinkV3Aggregator(_feed).decimals();

        // Scaleup or scaledown the decimals
        if (feedDecimals != 9) {
            price = (uint256(_price) * 1 gwei) / 10**feedDecimals;
        } else {
            price = uint256(_price);
        }
    }

    /**
     * @notice Gets the price of gOHM/USDC
     * @return price The price of gOHM in terms of USDC (1e6 precision)
     */
    function getPrice() external view returns (uint256 price) {
        // Check L2 Flag
        bool isRaised = IChainlinkL2Flag(flag).getFlag(offlineFlag);
        if(isRaised) revert SequencerOffline();

        // Get the prices
        uint256 ohmPrice = getPriceInUSD(ohmFeed);
        uint256 ohmCurrentIndex = getOHMIndex();
        uint256 gohmPrice = (ohmCurrentIndex * ohmPrice) / 1e9;
        uint256 usdcPrice = getPriceInUSD(usdcFeed);

        // Convert gOHM/USD and USDC/USD to gOHM/USDC (1e9 precision)
        uint256 _price = (gohmPrice * 1e9) / usdcPrice;

        // Convert 1e9 to 1e6 precision (USDC decimals is 6)
        price = (_price * 1e6) / 1e9;
    }
}
