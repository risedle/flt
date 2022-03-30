// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title Rise Token
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice 2x Long Token powered by Rari Fuse
 */
interface IRiseToken is IERC20 {

    /// ███ Types █████████████████████████████████████████████████████████████

    /// @notice Flashswap types
    enum FlashSwapType {
        Initialize,
        Buy,
        Sell
    }

    /**
     * @notice Parameters that used to initialize the Rise Token
     * @param borrowAmount The target borrow amount
     * @param collateralAmount The target collateral amount
     * @param shares The target initial supply of the Rise Token
     * @param leverageRatio The target leverage ratio of the Rise Token
     * @param nav The net-asset value of the Rise Token
     * @param ethAmount The maximum amount of ETH that used to initialize the
     *                  total collateral and total debt
     * @param initialize The initialize() executor
     */
    struct InitializeParams {
        uint256 borrowAmount;
        uint256 collateralAmount;
        uint256 shares;
        uint256 leverageRatio;
        uint256 nav;
        uint256 ethAmount;
        address initializer;
    }

    /**
     * @notice Parameters that used to buy the Rise Token
     * @param buyer The msg.sender
     * @param recipient The address that will receive the Rise Token
     * @param tokenIn The ERC20 that used to buy the Rise Token
     * @param collateralAmount The amount of token that will supplied to Rari Fuse
     * @param debtAmount The amount of token that will borrowed from Rari Fuse
     * @param shares The amount of Rise Token to be minted
     * @param fee The amount of Rise Token as fee
     * @param amountInMax The maximum amount of tokenIn, useful for setting the
     *                    slippage tolerance.
     * @param nav The net-asset value of the Rise Token
     */
    struct BuyParams {
        address buyer;
        address recipient;
        IERC20 tokenIn;
        uint256 collateralAmount;
        uint256 debtAmount;
        uint256 shares;
        uint256 fee;
        uint256 amountInMax;
        uint256 nav;
    }

    /**
     * @notice Parameters that used to buy the Rise Token
     * @param seller The msg.sender
     * @param recipient The address that will receive the tokenOut
     * @param tokenOut The ERC20 that will received by recipient
     * @param collateralAmount The amount of token that will redeemed from Rari Fuse
     * @param debtAmount The amount of token that will repay to Rari Fuse
     * @param shares The amount of Rise Token to be burned
     * @param fee The amount of Rise Token as fee
     * @param amountOutMin The minimum amount of tokenOut, useful for setting the
     *                    slippage tolerance.
     * @param nav The net-asset value of the Rise Token
     */
    struct SellParams {
        address seller;
        address recipient;
        IERC20 tokenOut;
        uint256 collateralAmount;
        uint256 debtAmount;
        uint256 shares;
        uint256 fee;
        uint256 amountOutMin;
        uint256 nav;
    }


    /// ███ Events █████████████████████████████████████████████████████████████

    /**
     * @notice Event emitted when the Rise Token is initialized
     * @param params The initialization parameters
     */
    event Initialized(InitializeParams params);

    /**
     * @notice Event emitted when maxBuy is updated
     * @param newMaxBuy The new maximum buy amount
     */
    event MaxBuyUpdated(uint256 newMaxBuy);

    /// @notice Event emitted when user buy the token
    event Buy(BuyParams params);

    /// @notice Event emitted when user sell the token
    event Sell(SellParams params);


    /// ███ Errors █████████████████████████████████████████████████████████████

    /// @notice Error is raised if the caller of onFlashSwapWETHForExactTokens is
    ///         not Uniswap Adapter contract
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

    /// @notice Error is raised if the owner run the initialize() twice
    error AlreadyInitialized();

    /// @notice Error is raised if mint,redeem and rebalance is executed before the FLT is initialized
    error NotInitialized();

    /// @notice Error is raised if slippage too high
    error SlippageTooHigh();

    /// @notice Error is raised if contract failed to send ETH
    error FailedToSendETH(address to, uint256 amount);

    /// @notice Error is raised if rebalance is executed but leverage ratio is invalid
    error NoNeedToRebalance(uint256 leverageRatio);

    /// @notice Error is raised if liqudity to buy or sell collateral is not enough
    error LiquidityIsNotEnough();


    /// ███ Owner actions ██████████████████████████████████████████████████████

    /**
     * @notice Set the maxBuy value
     * @param _newMaxBuy New maximum mint amount
     */
    function setMaxBuy(uint256 _newMaxBuy) external;

    /**
     * @notice Initialize the Rise Token using ETH
     */
    function initialize(InitializeParams memory _params) external payable;


    /// ███ Read-only functions ████████████████████████████████████████████████

    /**
     * @notice Gets the total collateral per share
     * @return _cps Collateral per share in collateral token decimals precision
     *         (ex: gOHM is 1e18 precision)
     */
    function collateralPerShare() external view returns (uint256 _cps);

    /**
     * @notice Gets the total debt per share
     * @return _dps Debt per share in debt token decimals precision
     *         (ex: USDC is 1e6 precision)
     */
    function debtPerShare() external view returns (uint256 _dps);

    /**
     * @notice Gets the net-asset value of the Rise Token in ETH
     * @return _nav The net-asset value of the Rise Token in 1e18 precision
     */
    function nav() external view returns (uint256 _nav);

    /**
     * @notice Gets the net-asset value of the Rise Token in specified token
     * @dev This function may revert if _quote token is not configured in Rari
     *      Fuse Price Oracle
     * @param _quote The token address used as quote
     * @return _nav The net-asset value of the Rise Token in token decimals
     *         precision (ex: USDC is 1e6)
     */
    function nav(address _quote) external view returns (uint256 _nav);

    /**
     * @notice Gets the leverage ratio of the Rise Token
     * @return _lr Leverage ratio in 1e18 precision
     */
    function leverageRatio() external view returns (uint256 _lr);

    /**
     * @notice Get the amount of ETH to buy _shares amount of Rise Token
     * @param _shares The amount of Rise Token to buy
     * @return _ethAmount The amount of ETH that will be used to buy the token
     */
    function previewBuy(uint256 _shares) external view returns (uint256 _ethAmount);

    /**
     * @notice Get the amount of tokenIn to buy _shares amount of Rise Token
     * @dev The function may reverted if tokenIn is not configured in Rari Fuse
     *      Price Oracle Adapter
     * @param _shares The amount of Rise Token to buy
     * @param _tokenIn The address of tokenIn
     * @return _amountIn The amount of tokenIn
     */
    function previewBuy(
        uint256 _shares,
        address _tokenIn
    ) external view returns (uint256 _amountIn);

    /**
     * @notice Get the amount of ETH for selling _shares of Rise Token
     * @param _shares The amount of Rise Token to sell
     * @return _ethAmount The amount of ETH that will be received by the user
     */
    function previewSell(uint256 _shares) external view returns (uint256 _ethAmount);

    /**
     * @notice Get the amount of tokenOut for selling _shares amount of Rise Token
     * @dev The function may reverted if tokenIn is not configured in Rari Fuse Price Oracle Adapter
     * @param _shares The amount of Rise Token to sell
     * @param _tokenOut The address of tokenOut
     * @return _amountOut The amount of tokenOut
     */
    function previewSell(
        uint256 _shares,
        address _tokenOut
    ) external view returns (uint256 _amountOut);


    /// ███ User actions ███████████████████████████████████████████████████████

    /**
     * @notice Buy Rise Token with ETH. New Rise Token supply will be minted.
     * @param _shares The amount of Rise Token to buy
     * @param _recipient The recipient of the transaction
     */
    function buy(
        uint256 _shares,
        address _recipient
    ) external payable;

    /**
     * @notice Buy Rise Token with tokenIn. New Rise Token supply will be minted.
     * @param _shares The amount of Rise Token to buy
     * @param _recipient The recipient of the transaction.
     * @param _tokenIn ERC20 used to buy the Rise Token
     */
    function buy(
        uint256 _shares,
        address _recipient,
        address _tokenIn,
        uint256 _amountInMax
    ) external;

    /**
     * @notice Sell Rise Token for ETH. The _shares amount of Rise Token will be burned.
     * @param _shares The amount of Rise Token to sell
     * @param _recipient The recipient of the transaction. It should be able to receive ETH.
     * @param _amountOutMin The minimum amount of ETH
     */
    function sell(
        uint256 _shares,
        address _recipient,
        uint256 _amountOutMin
    ) external payable;

    /**
     * @notice Sell Rise Token for tokenOut. The _shares amount of Rise Token will be burned.
     * @param _shares The amount of Rise Token to sell
     * @param _recipient The recipient of the transaction
     * @param _tokenOut The output token
     * @param _amountOutMin The minimum amount of output token
     */
    function sell(
        uint256 _shares,
        address _recipient,
        address _tokenOut,
        uint256 _amountOutMin
    ) external;


    /// ███ Market makers ██████████████████████████████████████████████████████

    /**
     * Rise Token is designed in such way that users get protection against
     * liquidation, while market makers are well-incentivized to execute the
     * rebalancing process.
     *
     * ===== Leveraging Up
     * When collateral (ex: gOHM) price is going up, the net-asset value of
     * Rise Token (ex: gOHMRISE) will going up and the leverage ratio of
     * the Rise Token will going down.
     *
     * If leverage ratio is below specified minimum leverage ratio (ex: 1.7x),
     * Rise Token need to borrow more asset from Rari Fuse (ex: USDC), in order
     * to buy more collateral then supply the collateral to Rari Fuse.
     *
     * If leverageRatio < minLeverageRatio:
     *     Rise Token want collateral (ex: gOHM)
     *     Rise Token have liquid asset (ex: USDC)
     *
     * Market makers can swap collateral to ETH if leverage ratio below minimal
     * Leverage ratio.
     *
     * ===== Leveraging Down
     * When collateral (ex: gOHM) price is going down, the net-asset value of
     * Rise Token (ex: gOHMRISE) will going down and the leverage ratio of
     * the Rise Token will going up.
     *
     * If leverage ratio is above specified maximum leverage ratio (ex: 2.3x),
     * Rise Token need to sell collateral in order to repay debt to Rari Fuse.
     *
     * If leverageRatio > maxLeverageRatio:
     *     Rise Token want liquid asset (ex: USDC)
     *     Rise Token have collateral (ex: gOHM)
     *
     * Market makers can swap ETH to collateral if leverage ratio above maximum
     * Leverage ratio.
     *
     * -----------
     *
     * In order to incentives the swap process, Rise Token will give specified
     * discount price 0.6%.
     *
     * swapColleteralForETH -> Market Makers can sell collateral +0.6% above the
     *                         market price
     *
     * swapETHForCollateral -> Market Makers can buy collateral -0.6% below the
     *                         market price
     *
     * In this case, market price is determined using Rari Fuse Oracle Adapter.
     *
     */

     /**
      * @notice Swaps collateral for ETH
      * @dev Anyone can execute this if leverage ratio is below minimum.
      * @param _amountIn The amount of collateral
      * @param _amountOutMin The minimum amount of ETH to be received
      * @return _amountOut The amount of ETH that received by msg.sender
      */
    function swapExactCollateralForETH(
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external returns (uint256 _amountOut);

     /**
      * @notice Swaps ETH for collateral
      * @dev Anyone can execute this if leverage ratio is below minimum.
      * @param _amountOutMin The minimum amount of collateral
      * @return _amountOut The amount of collateral
      */
    function swapExactETHForCollateral(
        uint256 _amountOutMin
    ) external payable returns (uint256 _amountOut);

    /**
     * @notice Return how much collateral we want to buy in cdecimals precision
     *         (ex: gOHM have 18 decimals so it's 1e18)
     * @dev Better to allow ~1% room for swapExactCollateralForETH
     */
    function wtb() external returns (uint256 _amount);

    /**
     * @notice Returns how much collateral we want to sell in cdecimals precision
     *         (ex: gOHM have 18 decimals so it's 1e18)
     * @dev Better to allow ~1% room for swapExactETHForCollateral
     */
    function wts() external returns (uint256 _amount);

}
