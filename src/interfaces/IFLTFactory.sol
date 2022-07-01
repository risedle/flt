// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IFLT } from "./IFLT.sol";

/**
 * @title FLT Factory Interface
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Factory contract to create new FLT
 */
interface IFLTFactory {

    /// ███ Events ███████████████████████████████████████████████████████████

    /// @notice Event emitted when new Rise Token is created
    event TokenCreated(
        address token,
        string  name,
        string  symbol,
        bytes   data,
        uint256 totalTokens
    );

    /**
     * @notice Event emitted when feeRecipient is updated
     * @param newRecipient The new fee recipient address
     */
    event FeeRecipientUpdated(address newRecipient);


    /// ███ Errors █████████████████████████████████████████████████████████████

    /// @notice Error is raised when Fee recipient is similar with existing
    error FeeRecipientNotChanged();


    /// ███ Owner actions ██████████████████████████████████████████████████████

    /**
     * @notice Sets fee recipient
     * @param _newRecipient New fee recipient
     */
    function setFeeRecipient(address _newRecipient) external;

    /// @notice Create new FLT
    function create(
        string memory _name,
        string memory _symbol,
        bytes  memory _data,
        address _implementation
    ) external returns (IFLT _token);

}
