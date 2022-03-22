// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUniswapAdapter } from "./interfaces/IUniswapAdapter.sol";
import { IOracle } from "./interfaces/IOracle.sol";
import { IfERC20 } from "./interfaces/IfERC20.sol";

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

    /// @notice The Rari Fuse collateral token
    address public immutable fCollateral;

    /// @notice The ERC20 compliant token that used by FLT as debt asset
    address public immutable debt;

    /// @notice The Rari Fuse debt token
    address public immutable fDebt;

    /// @notice The Uniswap Adapter
    address public uniswapAdapter;

    /// @notice The price oracle
    address public oracle;

    /// @notice True if the total collateral and debt are bootstraped
    bool private isBootstrapped;

    /// @notice The total collateral managed by this contract
    uint256 public totalCollateral;

    /// @notice The total debt managed by this contract
    uint256 public totalDebt;

    /// @notice The total shares / supply of the FLT token
    uint256 public totalShares;

    /**
     * @notice The maximum amount of the collateral token that can be deposited
     *         into the FLT contract through deposit function.
     *         - There is no limit by default (2**256-1).
     *         - Owner can set maxDeposit to zero to disable the deposit if
     *           something bad happen
     */
    uint256 public maxDeposit = type(uint256).max;

    /// @notice Flashswap type
    enum FlashSwapType {Bootstrap, Mint}

    /// ███ Events █████████████████████████████████████████████████████████████

    /// @notice Event emitted when maxDeposit is updated
    event MaxDepositUpdated(uint256 newMaxDeposit);

    /// @notice Event emitted when the total collateral and debt are bootstraped
    event Bootstrapped();

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
     * @param _debt The ERC20 comlienat token the FLT used to leverage
     * @param _uniswapAdapter The Uniswap Adapter
     * @param _oracle The collateral price oracle
     * @param _fCollateral The Rari Fuse token that used as collateral
     * @param _fDebt The Rari Fuse token that used as debt
     */
    constructor(string memory _name, string memory _symbol, address _collateral, address _debt, address _uniswapAdapter, address _oracle, address _fCollateral, address _fDebt) ERC20(_name, _symbol) {
        // Set the storages
        collateral = _collateral;
        debt = _debt;
        uniswapAdapter = _uniswapAdapter;
        oracle = _oracle;
        isBootstrapped = false;
        fCollateral = _fCollateral;
        fDebt = _fDebt;
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

    /**
     * @notice Bootstrap the initial total collateral and total debt of the FLT.
     * @param _collateralMax The max amount of collateral used
     * @param _nav The initial net-asset value of the FLT
     */
    function bootstrap(uint256 _collateralMax, uint256 _nav) external onlyOwner {
        // Get the collateral decimals
        uint256 decimals = IERC20Metadata(collateral).decimals();

        // Get the reserved collateral (5%) and leveraged collateral amount (95%)
        uint256 rc = (0.05 ether * _collateralMax) / 1 ether;
        uint256 lc = (0.95 ether * _collateralMax) / 1 ether;

        // Get the latest collateral price to get borrow amount
        uint256 price = IOracle(oracle).getPrice();
        uint256 b = (price * lc) / 10**decimals; // b: Borrow amount

        // Transfer data to the onBootstrap function
        bytes memory data = abi.encode(FlashSwapType.Bootstrap, abi.encode(rc, lc, price, b, _nav));

        // Do the flash swap and transfer data to onBootstrap function
        uint256 amountOutMin = lc - ((0.02 ether * lc) / 1 ether); // 2% (swap fees + slippage tolerance)
        IUniswapAdapter(uniswapAdapter).flashSwapExactTokensForTokensViaETH(b, amountOutMin, [debt, collateral], data);
    }

    /// ███ Internal functions █████████████████████████████████████████████████

    function onBootstrap(uint256 _amountOut, bytes memory _data) internal {
        // Parse the data from bootstrap function
        (uint256 rc, uint256 lc, uint256 price, uint256 b, uint256 nav) = abi.decode(_data, (uint256, uint256, uint256, uint256, uint256));

        // Get the owed collateral
        uint256 owedCollateral = lc - _amountOut;

        /// ███ Effects
        // Get the collateral decimals
        uint256 decimals = IERC20Metadata(collateral).decimals();
        totalCollateral = 2 * lc;
        totalDebt = b;
        totalShares = (totalCollateral * price * 10**decimals) / nav;


        /// ███ Interactions

        // Transfer collateral to the contract
        IERC20(collateral).safeTransferFrom(msg.sender, address(this), lc + owedCollateral);

        // Deposit all collateral to the Fuse
        IERC20(fCollateral).safeApprove(fCollateral, totalShares);
        IfERC20(fCollateral).mint(totalShares);
        IERC20(fCollateral).safeApprove(fCollateral, 0);

        // Borrow from the Fuse
        IfERC20(fDebt).borrow(b);

        // Repay the flash swap
        IERC20(debt).safeTransfer(uniswapAdapter, b);

        // Mint the token
        _mint(owner(), totalShares);

        emit Bootstrapped();
    }

    /// ███ External functions █████████████████████████████████████████████████

    /**
     * @notice This function is executed when the flashSwapExactTokensForTokensViaETH
     *         is triggered.
     * @dev Only uniswapAdapter can call this function
     * @param _amountOut The amount of tokenOut received by this contract
     * @param _data The calldata passed to this function
     */
    function onFlashSwapExactTokensForTokensViaETH(uint256 _amountOut, bytes calldata _data) external {
        /// ███ Checks

        // Check the caller
        if (msg.sender != uniswapAdapter) revert NotUniswapAdapter();

        // Continue execution based on the type
        (FlashSwapType flashSwapType, bytes memory data) = abi.decode(_data, (FlashSwapType,bytes));
        if (flashSwapType == FlashSwapType.Bootstrap) {
            onBootstrap(_amountOut, data);
            return;
        }
    }

    /// ███ User actions ███████████████████████████████████████████████████████

}
