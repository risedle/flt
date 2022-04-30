// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;


import { Ownable } from "openzeppelin/access/Ownable.sol";
import { IERC20Metadata } from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

import { IRariFusePriceOracleAdapter } from "../interfaces/IRariFusePriceOracleAdapter.sol";
import { IRariFusePriceOracle } from "../interfaces/IRariFusePriceOracle.sol";

/**
 * @title Rari Fuse Price Oracle Adapter
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Adapter for Rari Fuse Price Oracle
 */
contract RariFusePriceOracleAdapter is IRariFusePriceOracleAdapter, Ownable {
    /// ███ Storages ███████████████████████████████████████████████████████████

    /// @notice Map token to Rari Fuse Price oracle contract
    mapping(address => OracleMetadata) public oracles;


    /// ███ Owner actions ██████████████████████████████████████████████████████

    /// @inheritdoc IRariFusePriceOracleAdapter
    function configure(address _token, address _rariFusePriceOracle) external onlyOwner {
        oracles[_token] = OracleMetadata({
            oracle: IRariFusePriceOracle(_rariFusePriceOracle),
            decimals: IERC20Metadata(_token).decimals()
        });
        emit OracleConfigured(_token, oracles[_token]);
    }


    /// ███ Read-only functions ████████████████████████████████████████████████

    /// @inheritdoc IRariFusePriceOracleAdapter
    function isConfigured(address _token) external view returns (bool) {
        if (oracles[_token].decimals == 0) return false;
        return true;
    }


    /// ███ Adapters ███████████████████████████████████████████████████████████

    /// @inheritdoc IRariFusePriceOracleAdapter
    function price(address _token) public view returns (uint256 _price) {
        if (oracles[_token].decimals == 0) revert OracleNotExists(_token);
        _price = oracles[_token].oracle.price(_token);
    }

    /// @inheritdoc IRariFusePriceOracleAdapter
    function price(address _base, address _quote) external view returns (uint256 _price) {
        uint256 basePriceInETH = price(_base);
        uint256 quotePriceInETH = price(_quote);
        uint256 priceInETH = (basePriceInETH * 1e18) / quotePriceInETH;
        _price = (priceInETH * (10**oracles[_quote].decimals)) / 1e18;
    }
}
