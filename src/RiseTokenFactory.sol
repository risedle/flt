// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IfERC20 } from "./interfaces/IfERC20.sol";
import { IRiseTokenFactory } from "./interfaces/IRiseTokenFactory.sol";

import { RiseToken } from "./RiseToken.sol";
import { UniswapAdapter } from "./adapters/UniswapAdapter.sol";
import { RariFusePriceOracleAdapter } from "./adapters/RariFusePriceOracleAdapter.sol";

/**
 * @title Rise Token Factory
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Factory contract to create new Rise Token
 */
contract RiseTokenFactory is IRiseTokenFactory, Ownable {
    /// ███ Storages ███████████████████████████████████████████████████████████

    /// @notice List of created tokens
    address[] public tokens;

    /// @notice To make sure Rise Token only created once
    mapping(address => mapping(address => address)) public getToken;

    /// @notice Fee recipient
    address public feeRecipient;

    /// @notice Uniswap Adapter
    UniswapAdapter public uniswapAdapter;

    /// @notice Rari Fuse Price Oracle Adapter
    RariFusePriceOracleAdapter public oracleAdapter;


    /// ███ Constructors ███████████████████████████████████████████████████████

    constructor(address _feeRecipient, address _uniswapAdapter, address _oracleAdapter) {
        feeRecipient = _feeRecipient;
        uniswapAdapter = UniswapAdapter(_uniswapAdapter);
        oracleAdapter = RariFusePriceOracleAdapter(_oracleAdapter);
    }


    /// ███ Owner actions ██████████████████████████████████████████████████████

    /// @inheritdoc IRiseTokenFactory
    function setFeeRecipient(address _newRecipient) external onlyOwner {
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(_newRecipient);
    }

    /// @inheritdoc IRiseTokenFactory
    function create(address _fCollateral, address _fDebt) external onlyOwner returns (address _token) {
        /// ███ Checks

        // Get the underlying assets
        address collateral = IfERC20(_fCollateral).underlying();
        address debt = IfERC20(_fDebt).underlying();

        // Check uniswap adapter
        if (!uniswapAdapter.isConfigured(collateral)) revert UniswapAdapterNotConfigured(collateral);
        if (!uniswapAdapter.isConfigured(debt)) revert UniswapAdapterNotConfigured(debt);

        // Check price oracle
        if (!oracleAdapter.isConfigured(collateral)) revert RariFusePriceOracleAdapterNotConfigured(collateral);
        if (!oracleAdapter.isConfigured(debt)) revert RariFusePriceOracleAdapterNotConfigured(debt);

        // Check existing token
        if (getToken[collateral][debt] != address(0)) revert TokenExists(getToken[collateral][debt]);


        /// ███ Contract deployment

        bytes memory creationCode = type(RiseToken).creationCode;
        string memory tokenName = string(abi.encodePacked(IERC20Metadata(collateral).symbol(), " 2x Long Risedle"));
        string memory tokenSymbol = string(abi.encodePacked(IERC20Metadata(collateral).symbol(), "RISE"));
        bytes memory constructorArgs = abi.encode(tokenName, tokenSymbol, address(this), _fCollateral, _fDebt);
        bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);
        bytes32 salt = keccak256(abi.encodePacked(_fCollateral, _fDebt));
        assembly {
            _token := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        getToken[_fCollateral][_fDebt] = _token;
        getToken[_fDebt][_fCollateral] = _token; // populate mapping in the reverse direction
        tokens.push(_token);

        emit TokenCreated(_token, _fCollateral, _fDebt, tokens.length);
    }

}
