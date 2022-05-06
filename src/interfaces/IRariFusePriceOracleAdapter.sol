// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IRariFusePriceOracle } from "./IRariFusePriceOracle.sol";

/**
 * @title Rari Fuse Price Oracle Adapter
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Adapter for Rari Fuse Price Oracle
 */
interface IRariFusePriceOracleAdapter {
    /// ███ Types ████████████████████████████████████████████████████████████

    /**
     * @notice Oracle metadata
     * @param oracle The Rari Fuse oracle
     * @param precision The token precision (e.g. USDC is 1e6)
     */
    struct OracleMetadata {
        IRariFusePriceOracle oracle;
        uint256 precision;
    }


    /// ███ Events ███████████████████████████████████████████████████████████

    /**
     * @notice Event emitted when oracle data is updated
     * @param token The ERC20 address
     * @param metadata The oracle metadata
     */
    event OracleConfigured(
        address token,
        OracleMetadata metadata
    );


    /// ███ Errors ███████████████████████████████████████████████████████████

    /// @notice Error is raised when base or quote token oracle is not exists
    error OracleNotExists(address token);


    /// ███ Owner actions ████████████████████████████████████████████████████

    /**
     * @notice Configure oracle for token
     * @param _token The ERC20 token
     * @param _rariFusePriceOracle Contract that conform IRariFusePriceOracle
     * @param _decimals The ERC20 token decimals
     */
    function configure(
        address _token,
        address _rariFusePriceOracle,
        uint8 _decimals
    ) external;


    /// ███ Read-only functions ██████████████████████████████████████████████

    /**
     * @notice Returns true if oracle for the `_token` is configured
     * @param _token The token address
     */
    function isConfigured(address _token) external view returns (bool);


    /// ███ Adapters █████████████████████████████████████████████████████████

    /**
     * @notice Gets the price of `_token` in terms of ETH (1e18 precision)
     * @param _token Token address (e.g. gOHM)
     * @return _price Price in ETH (1e18 precision)
     */
    function price(address _token) external view returns (uint256 _price);

    /**
     * @notice Gets the price of `_base` in terms of `_quote`.
     *         For example gOHM/USDC will return current price of gOHM in USDC.
     *         (1e6 precision)
     * @param _base Base token address (e.g. gOHM/XXX)
     * @param _quote Quote token address (e.g. XXX/USDC)
     * @return _price Price in quote decimals precision (e.g. USDC is 1e6)
     */
    function price(
        address _base,
        address _quote
    ) external view returns (uint256 _price);

    /**
     * @notice Gets the total value of `_baseAmount` in terms of `_quote`.
     *         For example 100 gOHM/USDC will return current price of 10 gOHM
     *         in USDC (1e6 precision).
     * @param _base Base token address (e.g. gOHM/XXX)
     * @param _quote Quote token address (e.g. XXX/USDC)
     * @param _baseAmount The amount of base token (e.g. 100 gOHM)
     * @return _value The total value in quote decimals precision (e.g. USDC is 1e6)
     */
    function value(
        address _base,
        address _quote,
        uint256 _baseAmount
    ) external view returns (uint256 _value);

}
