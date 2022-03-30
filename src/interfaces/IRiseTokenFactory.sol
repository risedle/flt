// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

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
        address token,
        address fCollateral,
        address fDebt,
        uint256 totalTokens
    );

    /**
     * @notice Event emitted when feeRecipient is updated
     * @param newRecipient The new fee recipient address
     */
    event FeeRecipientUpdated(address newRecipient);


    /// ███ Errors █████████████████████████████████████████████████████████████

    /**
     * @notice Error is raised when collateral or debt token is not configured
     *         in Uniswap Adapter.
     * @param token The ERC20 that not available on Uniswap Adapter
     */
    error UniswapAdapterNotConfigured(address token);

    /**
     * @notice Error is raised when oracle for collateral or debt token is not
     *         configured in Rari Fuse Price Oracle Adapter
     * @param token The ERC20 that not available on Rari Fuse Price Oracle Adapter
     */
    error RariFusePriceOracleAdapterNotConfigured(address token);

    /**
     * @notice Error is raised when Rise Token already exists
     * @param token The Rise Token that already exists with the same collateral
     *               and debt pair
     */
    error TokenExists(address token);


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
    function create(address _fCollateral, address _fDebt) external returns (address _token);

}
