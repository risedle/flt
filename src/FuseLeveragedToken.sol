// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUniswapAdapter } from "./interfaces/IUniswapAdapter.sol";

/**
 * @title Fuse Leveraged Token (FLT)
 * @author bayu (github.com/pyk)
 * @notice Leveraged Token powered by Rari Fuse.
 */
contract FuseLeveragedToken is ERC20, Ownable {
    /// ███ Libraries ██████████████████████████████████████████████████████████
    using SafeERC20 for IERC20;

    /// ███ Storages ███████████████████████████████████████████████████████████

    /// @notice The ERC20 compliant token that used by FLT as collateral asset
    address public immutable collateral;

    /// @notice The ERC20 compliant token that used by FLT as debt asset
    address public immutable debt;

    /// @notice The Uniswap Adapter
    address public uniswapAdapter;

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
    error RecipientDeadAddress();

    /// @notice Error is raised if the caller of onFlashSwap is not specified
    ///         Uniswap Adapter contract
    error NotUniswapAdapter();

    /// @notice Error is raised if flash swap borrow token is not collateral
    error InvalidBorrowToken(address expected, address got);

    /// @notice Error is raised if flash swap repay token is not debt
    error InvalidRepayToken(address expected, address got);

    /// ███ Constructors ███████████████████████████████████████████████████████

    /**
     * @notice Creates a new FLT that manages specified collateral and debt
     * @param _name The name of the Fuse Leveraged Token (e.g. gOHM 2x Long)
     * @param _symbol The symbol of the Fuse Leveraged Token (e.g. gOHMRISE)
     * @param _collateral The ERC20 compliant token the FLT accepts as collateral
     */
    constructor(string memory _name, string memory _symbol, address _collateral, address _debt, address _uniswapAdapter, uint256 _nav) ERC20(_name, _symbol) {
        // Set the accepted collateral token
        collateral = _collateral;

        // Set the debt token
        debt = _debt;

        // Set the Uniswap Adapter
        uniswapAdapter = _uniswapAdapter;

        // Bootstrap the total collateral and total debt with specified
        // net-asset value
        bootstrap(_nav);
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

    /// ███ Internal functions █████████████████████████████████████████████████

    /**
     * @notice Bootstrap the initial total collateral and total debt of the FLT
     * @dev The deployer should have at least one collateral token
     * @param _nav The initial net-asset value of the FLT
     */
    function bootstrap(uint256 _nav) internal {
        // Collateral reserve to cover flash swap fees
        uint256 cr = 0.05 ether;
        // The amount of collateral need to be leveraged
        uint256 lc = 0.95 ether;
        // Target leverage ratio
        // uint256 lr = 1 ether;

        // TODO(pyk): Perlu oracle untuk tau berapa USDC yg perlu kita borrow
        // TODO(pyk): Perlu tau swap amount yang perlu kita flash given jumlah USDC yg bisa kita pakai untuk repay

    }

    /// ███ External functions █████████████████████████████████████████████████

    /// @notice onFlashSwap is executed when flash swap on Uniswap Adapter is triggered
    function onFlashSwap(address _borrowToken, uint256 _borrowAmount, address _repayToken, uint256 _repayAmount) external {
        /// ███ Checks

        // Only specified Uniswap Adapter can call this function
        if (msg.sender != uniswapAdapter) revert NotUniswapAdapter();

        // Borrow token should be the collateral
        if (_borrowToken != collateral) revert InvalidBorrowToken(collateral, _borrowToken);

        // Repay token should be the debt
        if (_repayToken != debt) revert InvalidRepayToken(debt, _repayToken);

        // TODO(pyk): Check repay amount using oracle

        /// ███ Effects

        /// ███ Interactions

        // TODO(pyk): Need to get total collateral to borrow and fuse
        // TODO(pyk): Need to repay the amount
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
        if (_recipient == address(0)) revert RecipientDeadAddress();

        /// ███ Effects

        /// ███ Interactions

        // Transfer collateral token to the contract
        IERC20(collateral).safeTransferFrom(msg.sender, address(this), _amount);

        // Trigger the flash swap to get more collateral
        uint256 fsAmount = _amount; // TODO(pyk): Use current leverage ratio to get flash swap amount
        IUniswapAdapter(uniswapAdapter).flash(collateral, fsAmount, debt);

        // TODO(pyk): continue here

        return 0;
    }


}
