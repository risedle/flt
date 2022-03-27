// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

/**
 * @title Rari Fuse Price Oracle Adapter Interface
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
interface IRariFusePriceOracleAdapter {
    /**
     * @notice Gets the price in ETH of `_token`
     * @param _token ERC20 token address
     * @return _price Price in 1e18 precision
     */
    function price(address _token) external view returns (uint256 _price);

    /**
     * @notice Gets the price of `_base` token in `_quote` token.
     * @param _base The base token
     * @param _quote The quote token
     * @return _price Price in quote decimals precision e.g. USDC is 1e6 precision.
     */
    function price(address _base, address _quote) external view returns (uint256 _price);

    /// @notice Returns true if oracle for the `_token` is configured
    function isConfigured(address _token) external view returns (bool);
}
