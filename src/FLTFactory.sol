// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { Clones } from "openzeppelin/proxy/Clones.sol";
import { Owned } from "solmate/auth/Owned.sol";

import { IFLTFactory } from "./interfaces/IFLTFactory.sol";
import { IFLT } from "./interfaces/IFLT.sol";

/**
 * @title FLT Factory
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Factory contract to create new RISE or DROP token
 */
contract FLTFactory is IFLTFactory, Owned {

    /// ███ Storages █████████████████████████████████████████████████████████

    address[] public tokens;
    address   public feeRecipient;
    mapping(address => bool) public isValid;


    /// ███ Constructor ██████████████████████████████████████████████████████

    constructor(address _feeRecipient) Owned(msg.sender) {
        feeRecipient = _feeRecipient;
    }

    /// ███ Owner actions ████████████████████████████████████████████████████

    /// @inheritdoc IFLTFactory
    function setFeeRecipient(address _newRecipient) external onlyOwner {
        if (_newRecipient == feeRecipient) revert FeeRecipientNotChanged();
        feeRecipient = _newRecipient;
        emit FeeRecipientUpdated(_newRecipient);
    }

    /// @inheritdoc IFLTFactory
    function create(
        string memory _name,
        string memory _symbol,
        bytes memory _data,
        address _implementation
    ) external onlyOwner returns (IFLT _flt) {
        // Clone implementation
        address token = Clones.clone(_implementation);

        isValid[token] = true;
        tokens.push(token);

        _flt = IFLT(token);
        _flt.deploy(address(this), _name, _symbol, _data);

        emit TokenCreated(token, _name, _symbol, _data, tokens.length);
    }
}
