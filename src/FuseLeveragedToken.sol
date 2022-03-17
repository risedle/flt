// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Fuse Leveraged Token (FLT)
 * @author bayu (github.com/pyk)
 * @notice Leveraged Token powered by Rari Fuse
 */
contract FuseLeveragedToken is ERC20, Ownable {
    /// ███ Libraries ██████████████████████████████████████████████████████████
    using SafeERC20 for IERC20;

    /// ███ Storages ███████████████████████████████████████████████████████████

    /// @notice The ERC20 compliant token that used by FLT as collateral
    address public immutable collateral;

    /**
     * @notice The maximum amount of the collateral token that can be deposited
     *         into the FLT contract through deposit function.
     *         - There is no limit by default (2**256-1).
     *         - Owner can set maxDeposit to zero to disable the deposit if
     *           something bad happen
     */
    uint256 public maxDeposit = type(uint256).max;

    /// ███ Events █████████████████████████████████████████████████████████████

    /// @notice Event emitted when maxDeposit is updated
    event MaxDepositUpdated(uint256 newMaxDeposit);

    /// ███ Errors █████████████████████████████████████████████████████████████

    error DepositAmountTooLarge(uint256 amount, uint256 maxAmount);

    error RecipientZeroAddress();

    /// ███ Constructors ███████████████████████████████████████████████████████

    /**
     * @notice Creates a new FLT that manages specified collateral and debt
     * @param _name The name of the Fuse Leveraged Token (e.g. gOHM 2x Long)
     * @param _symbol The symbol of the Fuse Leveraged Token (e.g. gOHMRISE)
     * @param _collateral The ERC20 compliant token the FLT accepts as collateral
     */
    constructor(string memory _name, string memory _symbol, address _collateral) ERC20(_name, _symbol) {
        // Set the accepted collateral token
        collateral = _collateral;
    }

    /// ███ Owner actions ██████████████████████████████████████████████████████

    /**
     * @notice Set the maxDeposit
     * @param _newMaxDeposit New maximum deposit
     */
    function setMaxDeposit(uint256 _newMaxDeposit) external onlyOwner {
        maxDeposit = _newMaxDeposit;
        emit MaxDepositUpdated(_newMaxDeposit);
    }

    /// ███ User actions ███████████████████████████████████████████████████████

    /**
     * @notice Mints `_shares` amount of FLT token to `_recipient` by depositing
     *         exactly `_amount` amount of collateral tokens.
     * @param _amount The amount of collateral
     * @param _recipient The address that will receive the minted FLT token
     * @return _shares The amount of minted FLT tokens
     */
    function deposit(uint256 _amount, address _recipient) external returns (uint256 _shares) {
        /// ███ Checks
        if (_amount > maxDeposit) revert DepositAmountTooLarge(_amount, maxDeposit);
        if (_amount == 0) return 0;

        /// ███ Effects

        /// ███ Interactions

        // Transfer collateral token to the contract
        IERC20(collateral).safeTransferFrom(msg.sender, address(this), _amount);

        //


        return 0;
    }

    function mint(uint256 _sharesAmount, address _recipient) external view returns (uint256 _collateral) {
        return 0;
    }
}
