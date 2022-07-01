// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { RiseToken } from "../RiseToken.sol";
import { IfERC20 } from "./IfERC20.sol";
import { UniswapAdapter } from "../adapters/UniswapAdapter.sol";
import { RariFusePriceOracleAdapter } from "../adapters/RariFusePriceOracleAdapter.sol";

/**
 * @title Rise Token Factory Interface
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Factory contract for creating Rise Token
 */
interface IRiseTokenFactory {
    /// ███ Events █████████████████████████████████████████████████████████████

    /**
     * @notice Event emitted when new Rise Token is created
     * @param token The address of Rise Token
     * @param fCollateral The address of Rari Fuse token that used as collateral
     * @param fDebt The address of Rari Fuse token that used as debt
     * @param totalTokens The total tokens created by this factory
     */
    event TokenCreated(
        RiseToken token,
        IfERC20   fCollateral,
        IfERC20   fDebt,
        uint256   totalTokens
    );

    /**
     * @notice Event emitted when feeRecipient is updated
     * @param newRecipient The new fee recipient address
     */
    event FeeRecipientUpdated(address newRecipient);


    /// ███ Errors █████████████████████████████████████████████████████████████

    /**
     * @notice Error is raised when Rise Token already exists
     * @param token The Rise Token that already exists with the same collateral
     *               and debt pair
     */
    error TokenExists(RiseToken token);

    /**
     * @notice Error is raised when Fee recipient is similar with existing
     */
    error FeeRecipientNotChanged();


    /// ███ Owner actions ██████████████████████████████████████████████████████

    /**
     * @notice Sets fee recipient
     * @param _newRecipient New fee recipient
     */
    function setFeeRecipient(address _newRecipient) external;

    /**
     * @notice Creates new Rise Token
     * @param _fCollateral fToken from Rari Fuse that used as collateral asset
     * @param _fDebt fToken from Rari Fuse that used as debt asset
     * @return _token The Rise Token address
     */
    function create(
        IfERC20                    _fCollateral,
        IfERC20                    _fDebt,
        UniswapAdapter             _uniswapAdapter,
        RariFusePriceOracleAdapter _oracleAdapter
    ) external returns (RiseToken _token);

}
