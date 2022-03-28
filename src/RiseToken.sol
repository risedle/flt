// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUniswapAdapter } from "./interfaces/IUniswapAdapter.sol";
import { IfERC20 } from "./interfaces/IfERC20.sol";
import { IFuseComptroller } from "./interfaces/IFuseComptroller.sol";
import { IRiseTokenFactory } from "./interfaces/IRiseTokenFactory.sol";
import { IRariFusePriceOracleAdapter } from "./interfaces/IRariFusePriceOracleAdapter.sol";
import { IWETH9 } from "./interfaces/IWETH9.sol";

/**
 * @title RISE Token (2x Long Token)
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice 2x Long Token powered by Rari Fuse
 */
contract RiseToken is ERC20, Ownable {
    /// ███ Libraries ██████████████████████████████████████████████████████████

    using SafeERC20 for IERC20;

    /// ███ Storages ███████████████████████████████████████████████████████████

    /// @notice WETH address
    IWETH9 public weth;

    /// @notice The Rise Token Factory
    IRiseTokenFactory public immutable factory;

    /// @notice Uniswap Adapter
    IUniswapAdapter public uniswapAdapter;

    /// @notice Rari Fuse Price Oracle Adapter
    IRariFusePriceOracleAdapter public oracleAdapter;

    /// @notice The ERC20 compliant token that used by FLT as collateral asset
    IERC20 public immutable collateral;

    /// @notice The ERC20 compliant token that used by FLT as debt asset
    IERC20 public immutable debt;

    /// @notice The Rari Fuse collateral token
    IfERC20 public immutable fCollateral;

    /// @notice The Rari Fuse debt token
    IfERC20 public immutable fDebt;

    /// @notice True if the total collateral and debt are bootstraped
    bool public isInitialized;

    /// @notice Cache the total collateral from Rari Fuse
    /// @dev We need this because balanceOfUnderlying fToken is non-view function
    uint256 public totalCollateral;
    uint256 public totalDebt;

    /**
     * @notice The maximum amount of total supply that can be minted in one transaction.
     *         - There is no limit by default (2**256-1).
     *         - Owner can set maxMint to zero to disable the deposit if
     *           something bad happen
     */
    uint256 public maxMint = type(uint256).max;

    /// @notice Fees in 1e18 precision (e.g. 0.1% is 0.001 * 1e8)
    uint256 public fees = 0.001 ether;

    /// @notice Minimum leverage ratio in 1e18 precision
    uint256 public minLeverageRatio = 1.7 ether;

    /// @notice Maximum leverage ratio in 1e18 precision
    uint256 public maxLeverageRatio = 2.3 ether;

    /// @notice Rebalancing step in 1e18 precision
    uint256 public step = 0.2 ether;

    /// @notice Max rebalancing value in debt decimals precision
    uint256 public maxRebalanceValue;

    /// @notice The collateral decimals
    uint8 private cdecimals;

    /// @notice The debt decimals
    uint8 private ddecimals;

    /// @notice Flashswap type
    enum FlashSwapType {Initialize, Mint}

    /// @notice Initialize params
    struct InitializeParams {
        uint256 borrowAmount;
        uint256 collateralAmount;
        address initializer;
        uint256 shares;
        uint256 leverageRatio;
        uint256 nav;
        uint256 ethAmount;
    }


    /// ███ Events █████████████████████████████████████████████████████████████

    /// @notice Event emitted when the rise token is initialized
    event Initialized(InitializeParams params);

    /// @notice Event emitted when new supply is minted
    event Minted(uint256 amount);

    /// @notice Event emitted when existing supply is burned
    event Redeemed(uint256 amount);

    /// @notice Event emitted when maxMint is updated
    event MaxMintUpdated(uint256 newMaxMint);

    /// @notice Event emitted when fees is updated
    event FeesUpdated(uint256 newFees);

    /// @notice Event emitted when uniswapAdapter is updated
    event UniswapAdapterUpdated(address newAdapter);

    /// @notice Event emitted when oracle is updated
    event OracleUpdated(address newOracle);

    /// @notice Event emitted when fee is collected
    event FeeCollected(uint256 amount);


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
    error InputAmountInvalid();

    /// @notice Error is raised if the owner run the bootstrap twice
    error AlreadyInitialized();

    /// @notice Error is raised if mint,redeem and rebalance is executed before the FLT is bootstrapped
    error NotInitialized();

    /// @notice Error is raised if flash swap/swap have slippage too high
    error SlippageTooHigh();

    /// @notice Error is raised if contract failed to send ETH
    error FailedToSendETH();


    /// ███ Constructors ███████████████████████████████████████████████████████

    /**
     * @notice Creates a new Rise Token that manages specified collateral and debt
     * @param _name The name of the Rise token (e.g. gOHM 2x Long)
     * @param _symbol The symbol of the Rise token (e.g. gOHMRISE)
     * @param _factory The Rise Token factory
     * @param _fCollateral The Rari Fuse token that used as collateral
     * @param _fDebt The Rari Fuse token that used as debt
     */
    constructor(string memory _name, string memory _symbol, address _factory, address _fCollateral, address _fDebt) ERC20(_name, _symbol) {
        // Set the storages
        factory = IRiseTokenFactory(_factory);
        uniswapAdapter = IUniswapAdapter(factory.uniswapAdapter());
        oracleAdapter = IRariFusePriceOracleAdapter(factory.oracleAdapter());
        fCollateral = IfERC20(_fCollateral);
        fDebt = IfERC20(_fDebt);
        collateral = IERC20(fCollateral.underlying());
        debt = IERC20(fDebt.underlying());
        weth = IWETH9(uniswapAdapter.weth());

        // Get the collateral & debt decimals
        cdecimals = IERC20Metadata(address(collateral)).decimals();
        ddecimals = IERC20Metadata(address(debt)).decimals();

        // Transfer ownership to factory owner
        transferOwnership(factory.owner());
    }


    /// ███ Internal functions █████████████████████████████████████████████████

    /**
     * @notice Gets the initialize params
     * @param _totalCollateralMin The minimum amount of total colllateral to initialize the token
     * @param _nav The initial net-asset value of the token in debt decimals precision (100 USDC is 100*1e6)
     * @param _lr The initial leverage ratio of the token in 1e18 precision (2x is 2*1e18)
     * @return _params The initialize parameters
     */
    function getInitializeParams(uint256 _totalCollateralMin, uint256 _nav, uint256 _lr) internal returns (InitializeParams memory _params) {
        // Get the initial total shares using 2x leverage ratio
        uint256 price = oracleAdapter.price(address(collateral), address(debt));
        uint256 targetCollateralAmount = 2 * _totalCollateralMin;
        uint256 targetBorrowAmount = (_totalCollateralMin * price) / (10**cdecimals);
        uint256 targetCollateralValue = (targetCollateralAmount * price) / (10**cdecimals);
        uint256 totalValue = targetCollateralValue - targetBorrowAmount;
        uint256 totalShares = (totalValue * (10**cdecimals)) / _nav;

        /// If target leverage ratio less than 2x, then Leverage down
        if (_lr < 2 ether) {
            uint256 delta = 2 ether - _lr;
            uint256 repayAmount = ((delta * totalShares) / 1e18) * _nav / (10**cdecimals);
            uint256 collateralSold = (repayAmount * (10**cdecimals)) / price;
            targetBorrowAmount -= repayAmount;
            targetCollateralAmount -= collateralSold;
        }

        /// If target leverage ratio larger than 2x, then Leverage up
        if (_lr > 2 ether) {
            uint256 delta = _lr - 2 ether;
            uint256 borrowAmount = ((delta * totalShares) / 1e18) * _nav / (10**cdecimals);
            uint256 collateralBought = (borrowAmount * (10**cdecimals)) / price;
            targetBorrowAmount += borrowAmount;
            targetCollateralAmount += collateralBought;
        }

        // Perform the flash swap
        _params = InitializeParams({
            borrowAmount: targetBorrowAmount,
            collateralAmount: targetCollateralAmount,
            initializer: msg.sender,
            shares: totalShares,
            leverageRatio: _lr,
            nav: _nav,
            ethAmount: 0 // Initialize to zero; it should be updated on initialize() using msg.value
        });
    }

    /**
     * @notice Continue the initialize function
     * @param _wethAmount The amount of WETH that we need to send back to Uniswap Adapter
     * @param _collateralAmount The collateral amount that received by this contract
     * @param _data Data passed from initialize function
     */
    function onInitialize(uint256 _wethAmount, uint256 _collateralAmount, bytes memory _data) internal {
        /// ███ Effects
        isInitialized = true;

        /// ███ Interactions

        // Parse the data from bootstrap function
        (InitializeParams memory params) = abi.decode(_data, (InitializeParams));

        // Enter Rari Fuse Markets
        address[] memory markets = new address[](2);
        markets[0] = address(fCollateral);
        markets[1] = address(fDebt);
        uint256[] memory marketStatus = IFuseComptroller(fCollateral.comptroller()).enterMarkets(markets);
        if (marketStatus[0] != 0 && marketStatus[1] != 0) revert FuseFailedToEnterMarkets(marketStatus[0], marketStatus[1]);

        // Deposit all collateral to the Fuse
        collateral.safeApprove(address(fCollateral), _collateralAmount);
        uint256 supplyResponse = fCollateral.mint(_collateralAmount);
        if (supplyResponse != 0) revert FuseAddCollateralFailed(supplyResponse);
        collateral.safeApprove(address(fCollateral), 0);

        // Borrow from the Fuse
        uint256 borrowResponse = fDebt.borrow(params.borrowAmount);
        if (borrowResponse != 0) revert FuseBorrowFailed(borrowResponse);

        // Swap debt asset to WETH
        debt.safeApprove(address(uniswapAdapter), params.borrowAmount);
        uint256 wethAmountFromBorrow = uniswapAdapter.swapExactTokensForWETH(address(debt), params.borrowAmount, 0);
        debt.safeApprove(address(uniswapAdapter), 0);

        // Cache the value
        totalCollateral = fCollateral.balanceOfUnderlying(address(this));
        totalDebt = fDebt.borrowBalanceCurrent(address(this));

        // Get owed WETH
        uint256 owedWETH = _wethAmount - wethAmountFromBorrow;
        if (owedWETH > params.ethAmount) revert SlippageTooHigh();

        // Transfer excess ETH back to the initializer
        uint256 excessETH = params.ethAmount - owedWETH;
        (bool sent, ) = params.initializer.call{value: excessETH}("");
        if (!sent) revert FailedToSendETH();

        // Send back WETH to uniswap adapter
        weth.deposit{ value: owedWETH }(); // Wrap the ETH to WETH
        weth.transfer(address(uniswapAdapter), _wethAmount);

        // Mint the token
        _mint(params.initializer, params.shares);

        emit Initialized(params);
    }

    /**
     * @notice Continue mint function after the flash swap callback
     * @param _amountOut The amount of collateral received via Flash Swap
     * @param _data Data passed from mint function
     */
    // function onMint(uint256 _amountOut, bytes memory _data) internal {
    //     // Parse the data from mint function
    //     (address minter, address recipient, uint256 shares, uint256 fee, uint256 collateralAmount, uint256 debtAmount) = abi.decode(_data, (address, address, uint256, uint256, uint256, uint256));

    //     // Get the owed collateral by the user
    //     uint256 owedCollateral = collateralAmount - _amountOut;

    //     // Transfer collateral to the contract
    //     IERC20(collateral).safeTransferFrom(minter, address(this), owedCollateral);

    //     // Deposit all collateral to the Fuse
    //     IERC20(collateral).safeApprove(fCollateral, collateralAmount);
    //     uint256 supplyResponse = fCollateral.mint(collateralAmount);
    //     if (supplyResponse != 0) revert FuseAddCollateralFailed(supplyResponse);
    //     IERC20(collateral).safeApprove(fCollateral, 0);

    //     // Borrow from the Rari Fuse
    //     uint256 borrowResponse = fDebt.borrow(debtAmount);
    //     if (borrowResponse != 0) revert FuseBorrowFailed(borrowResponse);

    //     // Repay the flash swap
    //     IERC20(debt).safeTransfer(address(uniswapAdapter), debtAmount);

    //     // Mint the token
    //     _mint(recipient, shares);
    //     _mint(address(this), fee);

    //     emit Minted(shares);
    // }


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
     * @notice Initialize the Rise Token using ETH
     * @param _collateralMin The minimum amount of collateral (in collateral decimals precision e.g. 0.01 WBTC is 0.01*1e8)
     * @param _nav The initial net-asset value of the FLT (in debt decimals precision e.g. 600 USDC is 600*1e6)
     * @param _lr Target leverage ratio in 1e18 precision (2x is 2*1e18)
     */
    function initialize(uint256 _collateralMin, uint256 _nav, uint256 _lr) external payable onlyOwner {
        /// ███ Checks

        // Can only initialized once
        if (isInitialized == true) revert AlreadyInitialized();

        // Check msg.value
        if (msg.value == 0) revert InputAmountInvalid();

        /// ███ Interactions

        // Get collateral, debt and shares based on parameters
        InitializeParams memory params = getInitializeParams(_collateralMin, _nav, _lr);
        params.ethAmount = msg.value; // Set the ETH sent by user

        // Do the flashswap
        bytes memory data = abi.encode(FlashSwapType.Initialize, abi.encode(params));
        uniswapAdapter.flashSwapWETHForExactTokens(address(collateral), params.collateralAmount, data);
    }

    /// ███ External functions █████████████████████████████████████████████████

    /**
     * @notice Gets amount of ETH that needed to initialize the token
     * @param _totalCollateralMin The minimum amount of total colllateral to initialize the token
     * @param _nav The initial net-asset value of the token in debt decimals precision (100 USDC is 100*1e6)
     * @param _lr The initial leverage ratio of the token in 1e18 precision (2x is 2*1e18)
     * @return _estimatedETHAmount The estimated amount of ETH needed to initialize the token
     */
    function previewInitialize(uint256 _totalCollateralMin, uint256 _nav, uint256 _lr) external view returns (uint256 _estimatedETHAmount) {
        // Get the initialize params
        InitializeParams memory params = getInitializeParams(_totalCollateralMin, _nav, _lr);

        // Get the price in ETH
        uint256 cPrice = oracleAdapter.price(address(collateral));
        uint256 dPrice = oracleAdapter.price(address(debt));

        // Get total value in ETH
        uint256 collateralValue = (params.collateralAmount * cPrice) / (10**cdecimals);
        uint256 borrowValue = (params.borrowAmount * dPrice) / (10**ddecimals);

        // Get the estimated ETH
        _estimatedETHAmount = collateralValue - borrowValue;
    }

    /**
     * @notice This function is executed when the flashSwapWETHForExactTokens is triggered.
     * @dev Only uniswapAdapter can call this function
     * @param _wethAmount The amount of WETH that we need to send back to the pair/pool
     * @param _amountOut The amount of tokenOut received by this contract
     * @param _data The calldata passed to this function
     */
    function onFlashSwapWETHForExactTokens(uint256 _wethAmount, uint256 _amountOut, bytes calldata _data) external {
        /// ███ Checks

        // Check the caller
        if (msg.sender != address(uniswapAdapter)) revert NotUniswapAdapter();

        // Continue execution based on the type
        (FlashSwapType flashSwapType, bytes memory data) = abi.decode(_data, (FlashSwapType,bytes));
        if (flashSwapType == FlashSwapType.Initialize) {
            onInitialize(_wethAmount, _amountOut, data);
            return;
        }

        if (flashSwapType == FlashSwapType.Mint) {
            // onMint(_amountOut, data);
            return;
        }
    }

    /// ███ Read-only functions ████████████████████████████████████████████████

    /// @notice Override the decimals number based on the collateral
    function decimals() public view virtual override returns (uint8) {
        return cdecimals;
    }

    /**
     * @notice Gets the total collateral per shares
     * @return _cps Collateral per shares (in collateral decimals precision e.g. gOHM with 18 decimals is 1e18)
     */
    function collateralPerShares() public view returns (uint256 _cps) {
        if (!isInitialized) return 0;
        _cps = (totalCollateral * (10**cdecimals)) / totalSupply();
    }

    /**
     * @notice Gets the collateral value per shares
     * @return _cvs Collateral value per shares (in debt decimals precision e.g. USDC with 6 decimals is 6)
     */
    function collateralValuePerShares() public view returns (uint256 _cvs) {
        if (!isInitialized) return 0;
        // Get the current price
        uint256 price = oracleAdapter.price(address(collateral), address(debt));
        // Calculate the total value of collateral per shares
        _cvs = (collateralPerShares() * price) / (10**cdecimals);
    }

    /**
     * @notice Gets the total debt per shares
     * @return _dps Debt per shares (in debt decimals precision e.g. USDC with 6 decimals is 1e6)
     */
    function debtPerShares() public view returns (uint256 _dps) {
        if (!isInitialized) return 0;
        _dps = (totalDebt * (10**cdecimals)) / totalSupply();
    }

    /**
     * @notice Gets the net-asset value of the shares
     * @return _nav The net-asset value of the shares in debt decimals precision (e.g. USDC is 1e6)
     */
    function nav() public view returns (uint256 _nav) {
        if (!isInitialized) return 0;
        _nav = collateralValuePerShares() - debtPerShares();
    }

    /**
     * @notice Gets the leverage ratio
     * @return _lr Leverage ratio in 1e18 precision
     */
    function leverageRatio() public view returns (uint256 _lr) {
        if (!isInitialized) return 0;
        _lr = (collateralValuePerShares() * 1e18) / nav();
    }

    /**
     * @notice Preview mint
     * @param _shares The amount of token to be minted
     * @return _collateral The amount of collateral that will be used to mint the token
     */
    // function previewMint(uint256 _shares) external returns (uint256 _collateral) {
    //     // Early return
    //     if (_shares == 0) return 0;
    //     if (!isInitialized) return 0;

    //     // Add fees
    //     uint256 fee = ((fees * _shares) / 1e18);
    //     uint256 newShares = _shares + fee;

    //     // Get the collateral & debt amount
    //     uint256 collateralAmount = (newShares * collateralPerShares()) / (10**cdecimals);
    //     uint256 debtAmount = (newShares * debtPerShares()) / (10**cdecimals);

    //     // Get the collateral amount using the borrowed asset
    //     // uint256 flashSwappedAmount = IUniswapAdapter(uniswapAdapter).getAmountOutViaETH([debt, collateral], debtAmount);

    //     // Get the owed collateral
    //     // _collateral = collateralAmount - flashSwappedAmount;
    // }

    /**
     * @notice Preview redeem
     * @param _shares The amount of token to be redeemed
     * @return _collateral The amount of collateral that user will received
     */
    // function previewRedeem(uint256 _shares) external returns (uint256 _collateral) {
    //     // Early return
    //     if (_shares == 0) return 0;
    //     if (!isInitialized) return 0;

    //     // Add fees
    //     uint256 fee = ((fees * _shares) / 1e18);
    //     uint256 newShares = _shares - fee;

    //     // Get the collateral & debt amount
    //     uint256 collateralAmount = (newShares * collateralPerShares()) / (10**cdecimals);
    //     uint256 debtAmount = (newShares * debtPerShares()) / (10**cdecimals);

    //     // Get the collateral amount using the borrowed asset
    //     // uint256 collateralSold = IUniswapAdapter(uniswapAdapter).getAmountInViaETH([collateral, debt], debtAmount);

    //     // Get the owed collateral
    //     // _collateral = collateralAmount - collateralSold;
    // }


    /// ███ User actions ███████████████████████████████████████████████████████

    /**
     * @notice Mints new RISE token
     * @param _shares The amount of RISE token to be minted
     * @param _recipient The recipient of newly minted RISE token
     * @param _token ERC20 used to mint the RISE token
     */
    // function mint(uint256 _shares, address _recipient, address _token) external {
    //     /// ███ Checks

    //     // Check boostrap status
    //     if (!isInitialized) revert NotInitialized();

    //     // Check mint amount
    //     if (_shares > maxMint) revert MintAmountInvalid();

    //     /// ███ Effects

    //     /// ███ Interactions

    //     // Add fees
    //     uint256 fee = ((fees * _shares) / 1e18);
    //     uint256 newShares = _shares + fee;

    //     // Get the collateral & debt amount
    //     uint256 collateralAmount = (newShares * collateralPerShares()) / (10**cdecimals);
    //     uint256 debtAmount = (newShares * debtPerShares()) / (10**cdecimals);

    //     // Perform the flash swap
    //     bytes memory data = abi.encode(FlashSwapType.Mint, abi.encode(msg.sender, _recipient, _shares, fee, collateralAmount, debtAmount, _token));
    //     // uniswapAdapter.flashSwapETHForExactTokens(collateral, collateralAmount);
    // }

    /**
     * @notice Redeems token to underlying collateral (e.g. gOHM)
     * @param _shares The amount of FLT token to be burned
     * @return _collateral The amount of collateral redeemed
     */
    // function redeem(uint256 _shares) external returns (uint256 _collateral) {
    //     /// ███ Checks
    //     if (!isInitialized) revert NotInitialized();
    //     if (_shares == 0) return 0;

    //     /// ███ Interactions

    //     // Add fees
    //     uint256 fee = ((fees * _shares) / 1e18);
    //     uint256 newShares = _shares - fee;

    //     // Get the backing per shares
    //     uint256 collateralAmount = (newShares * collateralPerShares()) / (10**cdecimals);
    //     uint256 debtAmount = (newShares * debtPerShares()) / (10**cdecimals);

    //     // Redeem collateral from Fuse
    //     uint256 redeemResponse = fCollateral.redeemUnderlying(collateralAmount);
    //     if (redeemResponse != 0) revert FuseRedeemCollateralFailed(redeemResponse);

    //     // Swap the collateral to repay the debt
    //     // uint256 amountInMax = IUniswapAdapter(uniswapAdapter).getAmountInViaETH([collateral, debt], debtAmount);
    //     // IERC20(collateral).safeApprove(uniswapAdapter, amountInMax);
    //     // uint256 collateralSold = IUniswapAdapter(uniswapAdapter).swapTokensForExactTokensViaETH(debtAmount, amountInMax, [collateral, debt]);
    //     // IERC20(collateral).safeApprove(uniswapAdapter, 0);

    //     // Repay the debt
    //     IERC20(debt).safeApprove(fDebt, debtAmount);
    //     uint256 repayResponse = fDebt.repayBorrow(debtAmount);
    //     if (repayResponse != 0) revert FuseRepayDebtFailed(repayResponse);
    //     IERC20(debt).safeApprove(fDebt, 0);

    //     // Tansfer fee and burn the token
    //     _transfer(msg.sender, address(this), fee);
    //     _burn(msg.sender, newShares);

    //     // Transfer the leftover collateral back to the user
    //     // _collateral = collateralAmount - collateralSold;
    //     // IERC20(collateral).safeTransfer(msg.sender, _collateral);

    //     emit Redeemed(_shares);
    // }
}
