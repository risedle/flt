// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

/**
 * @title Rari Fuse Price Oracle Interface
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
interface IRariFusePriceOracle {
    /**
     * @notice Gets the price in ETH of `_token`
     * @param _token ERC20 token address
     * @return _price Price in 1e18 precision
     */
    function price(address _token) external view returns (uint256 _price);
}
