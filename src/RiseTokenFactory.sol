// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { Ownable } from "openzeppelin/access/Ownable.sol";
import { IERC20Metadata } from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

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

    RiseToken[] public tokens;
    mapping(IfERC20 => mapping(IfERC20 => RiseToken)) public getToken;
    address public feeRecipient;


    /// ███ Constructors ███████████████████████████████████████████████████████

    constructor(address _feeRecipient) {
        feeRecipient = _feeRecipient;
    }


    /// ███ Owner actions ██████████████████████████████████████████████████████

    /// @inheritdoc IRiseTokenFactory
    function setFeeRecipient(address _newRecipient) external onlyOwner {
        if (_newRecipient == feeRecipient) revert FeeRecipientNotChanged();
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(_newRecipient);
    }

    /// @inheritdoc IRiseTokenFactory
    function create(
        IfERC20 _fCollateral,
        IfERC20 _fDebt,
        UniswapAdapter _uniswapAdapter,
        RariFusePriceOracleAdapter _oracleAdapter
    ) external onlyOwner returns (RiseToken _riseToken) {
        if (address(getToken[_fCollateral][_fDebt]) != address(0)) revert TokenExists(getToken[_fCollateral][_fDebt]);

        /// ███ Contract deployment
        string memory collateralSymbol = IERC20Metadata(_fCollateral.underlying()).symbol();
        string memory tokenName = string(abi.encodePacked(collateralSymbol, " 2x Long Risedle"));
        string memory tokenSymbol = string(abi.encodePacked(collateralSymbol, "RISE"));
        _riseToken = new RiseToken(
            tokenName,
            tokenSymbol,
            address(this),
            address(_fCollateral),
            address(_fDebt),
            address(_uniswapAdapter),
            address(_oracleAdapter)
        );

        getToken[_fCollateral][_fDebt] = _riseToken;
        getToken[_fDebt][_fCollateral] = _riseToken; // populate mapping in the reverse direction
        tokens.push(_riseToken);

        emit TokenCreated(_riseToken, _fCollateral, _fDebt, tokens.length);
    }
}
