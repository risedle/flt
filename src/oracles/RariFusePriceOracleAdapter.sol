// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IRariFusePriceOracle } from "../interfaces/IRariFusePriceOracle.sol";

/**
 * @title Rari Fuse Price Oracle Adapter
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Adapter for Rari Fuse Price Oracle
 */
contract RariFusePriceOracleAdapter is Ownable {
    /// ███ Storages ███████████████████████████████████████████████████████████

    /// @notice Oracle metadata
    struct OracleMetadata {
        IRariFusePriceOracle oracle;
        uint8 decimals; // Token decimals
    }

    /// @notice Map token to Rari Fuse Price oracle contract
    mapping(address => OracleMetadata) public oracles;


    /// ███ Events █████████████████████████████████████████████████████████████

    /// @notice Event emitted when oracle data is updated
    event OracleUpdated(address token, OracleMetadata metadata);


    /// ███ Errors █████████████████████████████████████████████████████████████

    /// @notice Error is raised when base or quote token oracle is not exists
    error OracleNotExists(address token);


    /// ███ Owner actions ██████████████████████████████████████████████████████

    /**
     * @notice Sets Rari Fuse Price Oracle for `_token`.
     * @param _token The ERC20 token
     * @param _rariFusePriceOracle Contract that conform IRariFusePriceOracle interface
     */
    function setOracle(address _token, address _rariFusePriceOracle) external onlyOwner {
        /// ███ Effects
        oracles[_token] = OracleMetadata({oracle: IRariFusePriceOracle(_rariFusePriceOracle), decimals: IERC20Metadata(_token).decimals()});
        emit OracleUpdated(_token, oracles[_token]);
    }


    /// ███ Adapters ███████████████████████████████████████████████████████████


    /**
     * @notice Gets the price of `_base` in terms of `_quote`.
     *         For example gOHM/USDC will return current price of gOHM in USDC.
     *         (1e6 precision)
     * @param _base Base token address (e.g. gOHM/XXX)
     * @param _quote Quote token address (e.g. XXX/USDC)
     * @return _price Price in quote decimals precision (e.g. USDC is 1e6)
     */
    function price(address _base, address _quote) external view returns (uint256 _price) {
        /// ███ Checks
        if (oracles[_base].decimals == 0) revert OracleNotExists(_base);
        if (oracles[_quote].decimals == 0) revert OracleNotExists(_quote);

        /// ███ Interaction
        uint256 basePriceInETH = oracles[_base].oracle.price(_base);
        uint256 quotePriceInETH = oracles[_quote].oracle.price(_quote);

        // Convert basePrice to quote price
        uint256 priceInETH = (basePriceInETH * 1e18) / quotePriceInETH;

        // Convert 1e18 precision to _quote precision
        // For example USDC will have 6 decimals. So we convert 1e18 precision to 1e6 precision
        _price = (priceInETH * (10**oracles[_quote].decimals)) / 1e18;
    }

}
