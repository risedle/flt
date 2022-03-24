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

    /// @notice Fees in 1e18 precision (e.g. 0.1% is 0.001 * 1e8)
    uint256 public fees = 0.001 ether;

    /// @notice The collateral decimals
    uint8 private cdecimals;

    /// @notice Flashswap type
    enum FlashSwapType {Bootstrap, Mint}

    /// ███ Events █████████████████████████████████████████████████████████████

    /// @notice Event emitted when the total collateral and debt are bootstraped
    event Bootstrapped();

    /// @notice Event emitten when new supply is minted
    event Minted(uint256 amount);

    /// @notice Event emitted when maxMint is updated
    event MaxMintUpdated(uint256 newMaxMint);

    /// @notice Event emitted when fees is updated
    event FeesUpdated(uint256 newFees);

    /// ███ Errors █████████████████████████████████████████████████████████████

    /// @notice Error is raised if the caller of onFlashSwap is not specified
    ///         Uniswap Adapter contract
    error NotUniswapAdapter();

    /// @notice Error is raised if flash swap borrow token is not collateral
    error InvalidBorrowToken(address expected, address got);

    /// @notice Error is raised if flash swap repay token is not debt
    error InvalidRepayToken(address expected, address got);

    /// @notice Error is raised if cannot add collateral to the Rari Fuse
    error FuseAddCollateralFailed(uint256 code);

    /// @notice Error is raised if cannot redeem collateral from Rari Fuse
    error FuseRedeemCollateralFailed(uint256 code);

    /// @notice Error is raised if cannot borrow from the Rari Fuse
    error FuseBorrowFailed(uint256 code);

    /// @notice Error is raised if cannot enter markets
    error FuseFailedToEnterMarkets(uint256 collateralCode, uint256 debtCode);

    /// @notice Error is raised if cannot repay the debt to Rari Fuse
    error FuseRepayDebtFailed(uint256 code);

    /// @notice Error is raised if mint amount is invalid
    error MintAmountInvalid();

    /// @notice Error is raised if the owner run the bootstrap twice
    error AlreadyBootstrapped();

    /// @notice Error is raised if mint,redeem and rebalance is executed before the FLT is bootstrapped
    error NotBootstrapped();

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
        cdecimals = IERC20Metadata(collateral).decimals();
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
     * @notice Set the fees value
     * @param _newFees New fees in 1e18 precision (e.g. 0.1% is 0.001 * 1e8)
     */
    function setFees(uint256 _newFees) external onlyOwner {
        fees = _newFees;
        emit FeesUpdated(_newFees);
    }

    /**
     * @notice Bootstrap the initial total collateral and total debt of the FLT.
     * @param _collateralMax The max amount of collateral used (e.g. 2 gOHM is 2*1e18)
     * @param _nav The initial net-asset value of the FLT (in debt precision e.g. 600 USDC is 600*1e6)
     */
    function bootstrap(uint256 _collateralMax, uint256 _nav) external onlyOwner {
        /// ███ Checks

        // Can only be bootstraped once
        if (isBootstrapped == true) revert AlreadyBootstrapped();

        // Get the leveraged collateral amount (95%), 5% reserved to repay the flash swap fees
        uint256 lc = (0.95 ether * _collateralMax) / 1 ether;
        uint256 collateralAmount = 2 * lc;

        // Get the latest collateral price to get borrow amount
        uint256 price = IOracle(oracle).getPrice();
        uint256 b = (price * lc) / (10**cdecimals); // b: Borrow amount
        uint256 shares = ((((collateralAmount * price) / (10**cdecimals)) - b) * (10**cdecimals)) / _nav;

        // Transfer data to the onBootstrap function
        bytes memory data = abi.encode(FlashSwapType.Bootstrap, abi.encode(msg.sender, collateralAmount, b, shares));

        // Do the flash swap and transfer data to onBootstrap function
        uint256 amountOutMin = lc - ((0.05 ether * lc) / 1 ether); // 5% (swap fees + slippage tolerance)
        IUniswapAdapter(uniswapAdapter).flashSwapExactTokensForTokensViaETH(b, amountOutMin, [debt, collateral], data);
    }

    /// ███ Internal functions █████████████████████████████████████████████████

    /**
     * @notice Continue bootstrap function after the flash swap callback
     * @param _amountOut The amount of collateral received via Flash Swap
     * @param _data Data passed from bootstrap function
     */
    function onBootstrap(uint256 _amountOut, bytes memory _data) internal {
        /// ███ Effects
        isBootstrapped = true;

        /// ███ Interactions

        // Parse the data from bootstrap function
        (address bootstraper, uint256 collateralAmount, uint256 borrowAmount, uint256 shares) = abi.decode(_data, (address,uint256,uint256,uint256));

        // Get the owed collateral
        uint256 owedCollateral = collateralAmount - _amountOut;

        // Transfer collateral to the contract
        IERC20(collateral).safeTransferFrom(bootstraper, address(this), owedCollateral);

        // Enter Rari Fuse Markets
        address[] memory markets = new address[](2);
        markets[0] = fCollateral;
        markets[1] = fDebt;
        uint256[] memory marketStatus = IFuseComptroller(IfERC20(fCollateral).comptroller()).enterMarkets(markets);
        if (marketStatus[0] != 0 && marketStatus[1] != 0) revert FuseFailedToEnterMarkets(marketStatus[0], marketStatus[1]);

        // Deposit all collateral to the Fuse
        IERC20(collateral).safeApprove(fCollateral, collateralAmount);
        uint256 supplyResponse = IfERC20(fCollateral).mint(collateralAmount);
        if (supplyResponse != 0) revert FuseAddCollateralFailed(supplyResponse);
        IERC20(collateral).safeApprove(fCollateral, 0);

        // Borrow from the Fuse
        uint256 borrowResponse = IfERC20(fDebt).borrow(borrowAmount);
        if (borrowResponse != 0) revert FuseBorrowFailed(borrowResponse);

        // Repay the flash swap
        IERC20(debt).safeTransfer(uniswapAdapter, borrowAmount);

        // Mint the token
        _mint(bootstraper, shares);

        emit Bootstrapped();
    }

    /**
     * @notice Continue mint function after the flash swap callback
     * @param _amountOut The amount of collateral received via Flash Swap
     * @param _data Data passed from mint function
     */
    function onMint(uint256 _amountOut, bytes memory _data) internal {
        // Parse the data from mint function
        (address minter, address recipient, uint256 shares, uint256 fee, uint256 collateralAmount, uint256 debtAmount) = abi.decode(_data, (address, address, uint256, uint256, uint256, uint256));

        // Get the owed collateral by the user
        uint256 owedCollateral = collateralAmount - _amountOut;

        // Transfer collateral to the contract
        IERC20(collateral).safeTransferFrom(minter, address(this), owedCollateral);

        // Deposit all collateral to the Fuse
        IERC20(collateral).safeApprove(fCollateral, collateralAmount);
        uint256 supplyResponse = IfERC20(fCollateral).mint(collateralAmount);
        if (supplyResponse != 0) revert FuseAddCollateralFailed(supplyResponse);
        IERC20(collateral).safeApprove(fCollateral, 0);

        // Borrow from the Rari Fuse
        uint256 borrowResponse = IfERC20(fDebt).borrow(debtAmount);
        if (borrowResponse != 0) revert FuseBorrowFailed(borrowResponse);

        // Repay the flash swap
        IERC20(debt).safeTransfer(uniswapAdapter, debtAmount);

        // Mint the token
        _mint(recipient, shares);
        _mint(address(this), fee);

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

    /// @notice Override the decimals number based on the collateral
    function decimals() public view virtual override returns (uint8) {
        return cdecimals;
    }

    /**
     * @notice Gets the total collateral managed by this contract in Rari Fuse
     * @return _tc Total collateral in cdecimals precision (e.g. gOHM is 1e18)
     */
    function totalCollateral() public returns (uint256 _tc) {
        if (!isBootstrapped) return 0;
        _tc = IfERC20(fCollateral).balanceOfUnderlying(address(this));
    }

    /**
     * @notice Gets the total debt managed by this contract in Rari Fuse
     * @return _td Total debt in debt decimals precision (e.g. USDC is 1e6)
     */
    function totalDebt() public returns (uint256 _td) {
        if (!isBootstrapped) return 0;
        _td = IfERC20(fDebt).totalBorrowsCurrent();
    }

    /**
     * @notice Gets the total collateral per shares
     * @return _cps Collateral per shares (in collateral decimals precision e.g. gOHM with 18 decimals is 1e18)
     */
    function collateralPerShares() public returns (uint256 _cps) {
        if (!isBootstrapped) return 0;
        _cps = (totalCollateral() * (10**cdecimals)) / totalSupply();
    }

    /**
     * @notice Gets the collateral value per shares
     * @return _cvs Collateral value per shares (in debt decimals precision e.g. USDC with 6 decimals is 6)
     */
    function collateralValuePerShares() public returns (uint256 _cvs) {
        if (!isBootstrapped) return 0;
        // Get the current price
        uint256 price = IOracle(oracle).getPrice();
        // Calculate the total value of collateral per shares
        _cvs = (collateralPerShares() * price) / (10**cdecimals);
    }

    /**
     * @notice Gets the total debt per shares
     * @return _dps Debt per shares (in debt decimals precision e.g. USDC with 6 decimals is 1e6)
     */
    function debtPerShares() public returns (uint256 _dps) {
        if (!isBootstrapped) return 0;
        _dps = (totalDebt() * (10**cdecimals)) / totalSupply();
    }

    /**
     * @notice Gets the net-asset value of the shares
     * @return _nav The net-asset value of the shares in debt decimals precision (e.g. USDC is 1e6)
     */
    function nav() public returns (uint256 _nav) {
        if (!isBootstrapped) return 0;
        _nav = collateralValuePerShares() - debtPerShares();
    }

    /**
     * @notice Gets the leverage ratio
     * @return _lr Leverage ratio in 1e18 precision
     */
    function leverageRatio() public returns (uint256 _lr) {
        if (!isBootstrapped) return 0;
        _lr = (collateralValuePerShares() * 1e18) / nav();
    }

    /**
     * @notice Preview mint
     * @param _shares The amount of token to be minted
     * @return _collateral The amount of collateral that will be used to mint the token
     */
    function previewMint(uint256 _shares) external returns (uint256 _collateral) {
        // Early return
        if (_shares == 0) return 0;

        // Add fees
        uint256 fee = ((fees * _shares) / 1e18);
        uint256 newShares = _shares + fee;

        // Get the collateral & debt amount
        uint256 collateralAmount = (newShares * collateralPerShares()) / (10**cdecimals);
        uint256 debtAmount = (newShares * debtPerShares()) / (10**cdecimals);

        // Get the collateral amount using the borrowed asset
        uint256 flashSwappedAmount = IUniswapAdapter(uniswapAdapter).getAmountOutViaETH([debt, collateral], debtAmount);

        // Get the owed collateral
        _collateral = collateralAmount - flashSwappedAmount;
    }


    /// ███ User actions ███████████████████████████████████████████████████████

    /**
     * @notice Mints new FLT token using collateral token (e.g. gOHM)
     * @param _shares The new supply of FLT token to be minted
     * @param _recipient The recipient of newly minted token
     * @return _collateral The amount of collateral used to mint the token
     */
    function mint(uint256 _shares, address _recipient) external returns (uint256 _collateral) {
        /// ███ Checks

        // Check boostrap status
        if (!isBootstrapped) revert NotBootstrapped();

        // Check mint amount
        if (_shares == 0) return 0;
        if (_shares > maxMint) revert MintAmountInvalid();

        /// ███ Effects

        /// ███ Interactions

        // Add fees
        uint256 fee = ((fees * _shares) / 1e18);
        uint256 newShares = _shares + fee;

        // Get the collateral & debt amount
        uint256 collateralAmount = (newShares * collateralPerShares()) / (10**cdecimals);
        uint256 debtAmount = (newShares * debtPerShares()) / (10**cdecimals);

        // Get the collateral amount using the borrowed asset
        uint256 flashSwappedAmount = IUniswapAdapter(uniswapAdapter).getAmountOutViaETH([debt, collateral], debtAmount);

        // Get the owed collateral
        _collateral = collateralAmount - flashSwappedAmount;

        // Perform the flash swap
        bytes memory data = abi.encode(FlashSwapType.Mint, abi.encode(msg.sender, _recipient, _shares, fee, collateralAmount, debtAmount));
        IUniswapAdapter(uniswapAdapter).flashSwapExactTokensForTokensViaETH(debtAmount, 0, [debt, collateral], data);
    }

    /**
     * @notice Redeems token to underlying collateral (e.g. gOHM)
     * @param _shares The amount of FLT token to be burned
     * @return _collateral The amount of collateral redeemed
     */
    function redeem(uint256 _shares) external returns (uint256 _collateral) {
        /// ███ Checks

        // Check boostrap status
        if (!isBootstrapped) revert NotBootstrapped();

        if (_shares == 0) return 0;

        /// ███ Interactions

        // Add fees
        uint256 fee = ((fees * _shares) / 1e18);
        uint256 newShares = _shares - fee;

        // Get the backing per shares
        uint256 collateralAmount = (newShares * collateralPerShares()) / (10**cdecimals);
        uint256 debtAmount = (newShares * debtPerShares()) / (10**cdecimals);

        // Redeem collateral from Fuse
        uint256 redeemResponse = IfERC20(fCollateral).redeemUnderlying(collateralAmount);
        if (redeemResponse != 0) revert FuseRedeemCollateralFailed(redeemResponse);

        // Swap the collateral to repay the debt
        uint256 amountInMax = IUniswapAdapter(uniswapAdapter).getAmountInViaETH([collateral, debt], debtAmount);
        uint256 collateralSold = IUniswapAdapter(uniswapAdapter).swapTokensForExactTokensViaETH(debtAmount, amountInMax, [collateral, debt]);

        // Repay the debt
        uint256 repayResponse = IfERC20(fDebt).repayBorrow(debtAmount);
        if (repayResponse != 0) revert FuseRepayDebtFailed(repayResponse);

        // Tansfer fee and burn the token
        _transfer(msg.sender, address(this), fee);
        _burn(msg.sender, newShares);

        // Transfer the leftover collateral back to the user
        IERC20(collateral).safeTransfer(msg.sender, collateralAmount - collateralSold);
    }
}
