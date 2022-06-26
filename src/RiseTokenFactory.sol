// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { Ownable } from "openzeppelin/access/Ownable.sol";
import { IERC20Metadata } from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

import { IfERC20 } from "./interfaces/IfERC20.sol";
import { IRiseTokenFactory } from "./interfaces/IRiseTokenFactory.sol";
import { IUniswapV2Pair } from "./interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Router02 } from "./interfaces/IUniswapV2Router02.sol";

import { RiseToken } from "./RiseToken.sol";
import { RariFusePriceOracleAdapter } from "./adapters/RariFusePriceOracleAdapter.sol";

/**
 * @title Rise Token Factory
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Factory contract to create new Rise Token
 */
contract RiseTokenFactory is IRiseTokenFactory, Ownable {

    /// ███ Storages █████████████████████████████████████████████████████████

    RiseToken[] public tokens;
    mapping(IfERC20 => mapping(IfERC20 => RiseToken)) public getToken;
    address public feeRecipient;


    /// ███ Constructors █████████████████████████████████████████████████████

    constructor(address _feeRecipient) {
        feeRecipient = _feeRecipient;
    }


    /// ███ Owner actions ████████████████████████████████████████████████████

    /// @inheritdoc IRiseTokenFactory
    function setFeeRecipient(address _newRecipient) external onlyOwner {
        if (_newRecipient == feeRecipient) revert FeeRecipientNotChanged();
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(_newRecipient);
    }

    /// @inheritdoc IRiseTokenFactory
    function create(
        string memory _name,
        string memory _symbol,
        IfERC20 _fCollateral,
        IfERC20 _fDebt,
        RariFusePriceOracleAdapter _oracleAdapter,
        IUniswapV2Pair _pair,
        IUniswapV2Router02 _router
    ) external onlyOwner returns (RiseToken _riseToken) {
        bool tokenExists = address(getToken[_fCollateral][_fDebt]) != address(0) || address(getToken[_fDebt][_fCollateral]) != address(0) ? true : false;
        if (tokenExists) revert TokenExists(getToken[_fCollateral][_fDebt]);

        /// ███ Contract deployment
        _riseToken = new RiseToken(
            _name,
            _symbol,
            RiseTokenFactory(address(this)),
            _fCollateral,
            _fDebt,
            _oracleAdapter,
            _pair,
            _router
        );

        getToken[_fCollateral][_fDebt] = _riseToken;
        tokens.push(_riseToken);

        emit TokenCreated(_riseToken, _fCollateral, _fDebt, tokens.length);
    }
}
