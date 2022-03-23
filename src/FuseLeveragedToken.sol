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
import { IFuseComptroller } from "./interfaces/IFuseComptroller.sol";

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

    /// @notice The number of decimals; Should be the same as collateral
    address public decimals;

    /// @notice The ERC20 compliant token that used by FLT as debt asset
    address public immutable debt;

    /// @notice The Rari Fuse debt token
    address public immutable fDebt;

    /// @notice The Uniswap Adapter
    address public uniswapAdapter;

    /// @notice The price oracle
    address public oracle;

    /// @notice True if the total collateral and debt are bootstraped
    bool public isBootstrapped;

    /**
     * @notice The maximum amount of total supply that can be minted in one transaction.
     *         - There is no limit by default (2**256-1).
     *         - Owner can set maxMint to zero to disable the deposit if
     *           something bad happen
     */
    uint256 public maxMint = type(uint256).max;

    /// @notice Flashswap type
    enum FlashSwapType {Bootstrap, Mint}

    /// ███ Events █████████████████████████████████████████████████████████████

    /// @notice Event emitted when maxMint is updated
    event MaxMintUpdated(uint256 newMaxMint);

    /// @notice Event emitted when the total collateral and debt are bootstraped
    event Bootstrapped();

    /// ███ Errors █████████████████████████████████████████████████████████████

    /// @notice Error is raised if the caller of onFlashSwap is not specified
    ///         Uniswap Adapter contract
    error NotUniswapAdapter();

    /// @notice Error is raised if flash swap borrow token is not collateral
    error InvalidBorrowToken(address expected, address got);

    /// @notice Error is raised if flash swap repay token is not debt
    error InvalidRepayToken(address expected, address got);

    /// @notice Error is raised if cannot add collateral to the Rari Fuse
    error FuseAddCollateralFailed();

    /// @notice Error is raised if cannot borrow from the Rari Fuse
    error FuseBorrowFailed();

    /// @notice Error is raised if cannot enter markets
    error FuseFailedToEnterMarkets();

    /// @notice Error is raised if mint amount is invalid
    error MintAmountInvalid();

    /// ███ Constructors ███████████████████████████████████████████████████████

    /**
     * @notice Creates a new FLT that manages specified collateral and debt
     * @param _name The name of the Fuse Leveraged Token (e.g. gOHM 2x Long)
     * @param _symbol The symbol of the Fuse Leveraged Token (e.g. gOHMRISE)
     * @param _uniswapAdapter The Uniswap Adapter
     * @param _oracle The collateral price oracle
     * @param _fCollateral The Rari Fuse token that used as collateral
     * @param _fDebt The Rari Fuse token that used as debt
     */
    constructor(string memory _name, string memory _symbol, address _uniswapAdapter, address _oracle, address _fCollateral, address _fDebt) ERC20(_name, _symbol) {
        // Set the storages
        uniswapAdapter = _uniswapAdapter;
        oracle = _oracle;
        fCollateral = _fCollateral;
        fDebt = _fDebt;
        collateral = IfERC20(_fCollateral).underlying();
        debt = IfERC20(_fDebt).underlying();
        isBootstrapped = false;

        // Get the collateral decimals
        decimals = IERC20Metadata(collateral).decimals();
    }

    /// ███ Owner actions ██████████████████████████████████████████████████████

    /**
     * @notice Set the maxMint value
     * @param _newMaxMint New maximum mint amount
     */
    function setMaxMint(uint256 _newMaxMint) external onlyOwner {
        maxMint = _newMaxMint;
        emit MaxMintUpdated(_newMaxMint);
    }

    /**
     * @notice Bootstrap the initial total collateral and total debt of the FLT.
     * @param _collateralMax The max amount of collateral used
     * @param _nav The initial net-asset value of the FLT
     */
    function bootstrap(uint256 _collateralMax, uint256 _nav) external onlyOwner {
        // Get the leveraged collateral amount (95%), 5% used for repay the flash swap fees
        uint256 lc = (0.95 ether * _collateralMax) / 1 ether;

        // Get the latest collateral price to get borrow amount
        uint256 price = IOracle(oracle).getPrice();
        uint256 b = (price * lc) / (10**decimals); // b: Borrow amount

        // Transfer data to the onBootstrap function
        bytes memory data = abi.encode(FlashSwapType.Bootstrap, abi.encode(lc, price, b, _nav, msg.sender));

        // Do the flash swap and transfer data to onBootstrap function
        uint256 amountOutMin = lc - ((0.02 ether * lc) / 1 ether); // 2% (swap fees + slippage tolerance)
        IUniswapAdapter(uniswapAdapter).flashSwapExactTokensForTokensViaETH(b, amountOutMin, [debt, collateral], data);
    }

    /// ███ Internal functions █████████████████████████████████████████████████

    /**
     * @notice Continue bootstrap function after the flash swap callback
     * @param _amountOut The amount of collateral received via Flash Swap
     * @param _data Data passed from bootstrap function
     */
    function onBootstrap(uint256 _amountOut, bytes memory _data) internal {
        // Parse the data from bootstrap function
        (uint256 lc, uint256 price, uint256 b, uint256 nav, address bootstraper) = abi.decode(_data, (uint256, uint256, uint256, uint256, address));

        // Get the owed collateral
        uint256 targetCollateral = 2 * lc;
        uint256 owedCollateral = targetCollateral - _amountOut;

        /// ███ Effects

        // TODO(pyk): I think we dont need these
        totalCollateral = targetCollateral;
        totalDebt = b;
        totalShares = (totalCollateral * price * (10**decimals)) / nav;
        isBootstrapped = true;

        /// ███ Interactions

        // Transfer collateral to the contract
        IERC20(collateral).safeTransferFrom(bootstraper, address(this), owedCollateral);

        // Enter Rari Fuse Markets
        address[] memory markets = new address[](2);
        markets[0] = fCollateral;
        markets[1] = fDebt;
        uint256[] memory marketStatus = IFuseComptroller(IfERC20(fCollateral).comptroller()).enterMarkets(markets);
        if (marketStatus[0] != 0 && marketStatus[1] != 0) revert FuseFailedToEnterMarkets();

        // Deposit all collateral to the Fuse
        IERC20(collateral).safeApprove(fCollateral, totalCollateral);
        if (IfERC20(fCollateral).mint(totalCollateral) != 0) revert FuseAddCollateralFailed();
        IERC20(collateral).safeApprove(fCollateral, 0);

        // Borrow from the Fuse
        uint256 result = IfERC20(fDebt).borrow(b);
        if (result != 0) revert FuseBorrowFailed();

        // Repay the flash swap
        IERC20(debt).safeTransfer(uniswapAdapter, b);

        // Mint the token
        _mint(bootstraper, totalShares);

        emit Bootstrapped();
    }

    /**
     * @notice Continue mint function after the flash swap callback
     * @param _amountOut The amount of collateral received via Flash Swap
     * @param _data Data passed from mint function
     */
    function onMint(uint256 _amountOut, bytes memory _data) internal {
        // Parse the data from mint function
        (uint256 shares, address minter, address recipient, uint256 collateralAmount, uint256 debtAmount) = abi.decode(_data, (uint256, address, address, uint256, uint256));

        // Get the owed collateral by the user
        uint256 owedCollateral = collateralAmount - _amountOut;

        // Get fee
        uint256 fee = (totalCollateral * mintFee) / 1e18;

        // Transfer collateral to the contract
        IERC20(collateral).safeTransferFrom(minter, address(this), owedCollateral + fee);

        // Deposit all collateral to the Fuse
        IERC20(collateral).safeApprove(fCollateral, collateralAmount);
        if (IfERC20(fCollateral).mint(collateralAmount) != 0) revert FuseAddCollateralFailed();
        IERC20(collateral).safeApprove(fCollateral, 0);

        // Borrow from the Rari Fuse
        if (IfERC20(fDebt).borrow(debtAmount) != 0) revert FuseBorrowFailed();

        // Repay the flash swap
        IERC20(debt).safeTransfer(uniswapAdapter, debtAmount);

        // Mint the token
        _mint(recipient, shares);

        emit Minted(shares);
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

        if (flashSwapType == FlashSwapType.Mint) {
            onMint(_amountOut, data);
            return;
        }
    }

    /// ███ Read-only functions ████████████████████████████████████████████████

    /**
     * @notice Gets the total collateral per shares
     * @return _cps Collateral per shares (in collateral decimals precision e.g. gOHM with 18 decimals is 1e18)
     */
    function collateralPerShares() public view returns (uint256 _cps) {
        // Get total collateral managed by this contract in Rari Fuse
        uint256 totalCollateral = IfERC20(fCollateral).balanceOfUnderlying(address(this));
        // Calculare the collateral per shares
        _cps = (totalCollateral * (10**decimals)) / totalSupply();
    }

    /**
     * @notice Gets the collateral value per shares
     * @return _cvs Collateral value per shares (in debt decimals precision e.g. USDC with 6 decimals is 6)
     */
    function collateralValuePerShares() public view returns (uint256 _cvs) {
        // Get the current price
        uint256 price = IOracle(oracle).getPrice();
        // Calculate the total value of collateral per shares
        _cvs = (collateralPerShares() * price) / (10**decimals);
    }

    /**
     * @notice Gets the total debt per shares
     * @return _dps Debt per shares (in debt decimals precision e.g. USDC with 6 decimals is 1e6)
     */
    function debtPerShares() public view returns (uint256 _dps) {
        // Get total debt managed by this contract in Rari Fuse
        uint256 totalDebt = IfERC20(fDebt).totalBorrowsCurrent();
        // Calculate the debt per shares
        _dps = (totalDebt * (10**decimals)) / totalSupply();
    }

    /**
     * @notice Gets the net-asset value of the shares
     * @return _nav The net-asset value of the shares in debt decimals precision (e.g. USDC is 1e6)
     */
    function nav() public view returns (uint256 _nav) {
        _nav = collateralValuePerShares() - debtPerShares();
    }

    /**
     * @notice Gets the leverage ratio
     * @return _lr Leverage ratio in 1e18 precision
     */
    function leverageRatio() public view returns (uint256 _lr) {
        _lr = (collateralPerShares() * 1e18) / nav();
    }


    /// ███ User actions ███████████████████████████████████████████████████████

    /**
     * @notice Mints new FLT token
     * @param _shares The new supply of FLT token to be minted
     * @param _recipieint The recipient of newly minted token
     */
    function mint(uint256 _shares, address _recipient) external payable {
        /// ███ Checks

        // Check is bootstraped or not
        if (!isBootstrapped) revert NotBootstraped();

        // Check mint amount
        if (_shares == 0) revert MintAmountInvalid();
        if (_shares > maxMint) revert MintAmountInvalid();

        /// ███ Effects

        /// ███ Interaction

        // Get the collateral & debt amount
        uint256 collateralAmount = (_shares * collateralPerShares()) / (10**decimals);
        uint256 debtAmount = (_shares * debtPerShares()) / (10**decimals);

        // Perform the flash swap
        bytes memory data = abi.encode(FlashSwapType.Mint, abi.encode(_shares, msg.sender, _recipient, collateralAmount, debtAmount));
        IUniswapAdapter(uniswapAdapter).flashSwapExactTokensForTokensViaETH(debtAmount, 0, [debt, collateral], data);
    }
}
