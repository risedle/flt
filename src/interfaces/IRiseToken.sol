// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;


import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

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
        ERC20 tokenIn;
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
        ERC20 tokenOut;
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

    /// @notice Event emitted when user buy the token
    event Buy(BuyParams params);

    /// @notice Event emitted when user sell the token
    event Sell(SellParams params);

    /**
     * @notice Event emitted when params updated
     * @param maxLeverageRatio The maximum leverage ratio
     * @param minLeverageRatio The minimum leverage ratio
     * @param step The rebalancing step
     * @param discount The incentives for the market makers
     * @param maxBuy The maximum amount to buy in one transaction
     */
    event ParamsUpdated(
        uint256 maxLeverageRatio,
        uint256 minLeverageRatio,
        uint256 step,
        uint256 discount,
        uint256 maxBuy
    );

    /// ███ Errors █████████████████████████████████████████████████████████████

    /// @notice Error is raised if the caller of onFlashSwapWETHForExactTokens is
    ///         not Uniswap Adapter contract
    error NotUniswapAdapter();

    /// @notice Error is raised if mint amount is invalid
    error InputAmountInvalid();

    /// @notice Error is raised if the owner run the initialize() twice
    error AlreadyInitialized();

    /// @notice Error is raised if buy & sell is executed before the FLT is initialized
    error NotInitialized();

    /// @notice Error is raised if slippage too high
    error SlippageTooHigh();

    /// @notice Error is raised if contract failed to send ETH
    error FailedToSendETH(address to, uint256 amount);

    /// @notice Error is raised if rebalance is executed but leverage ratio is invalid
    // error NoNeedToRebalance(uint256 leverageRatio);
    error NoNeedToRebalance();

    /// @notice Error is raised if liqudity to buy or sell collateral is not enough
    error LiquidityIsNotEnough();

    /// @notice Error is raised if something happen when interacting with Rari Fuse
    error FuseError(uint256 code);


    /// ███ Owner actions ██████████████████████████████████████████████████████

    /**
     * @notice Update the Rise Token parameters
     * @param _minLeverageRatio Minimum leverage ratio
     * @param _maxLeverageRatio Maximum leverage ratio
     * @param _step Rebalancing step
     * @param _discount Discount for market makers to incentivize the rebalance
     */
    function setParams(
        uint256 _minLeverageRatio,
        uint256 _maxLeverageRatio,
        uint256 _step,
        uint256 _discount,
        uint256 _maxBuy
    ) external;

    /**
     * @notice Initialize the Rise Token using ETH
     * @param _params The initialization parameters
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
     * @notice Gets the value of the Rise Token in ETH
     * @param _shares The amount of Rise Token
     * @return _value The value of the Rise Token in 1e18 precision
     */
    function value(uint256 _shares) external view returns (uint256 _value);

    /**
     * @notice Gets the net-asset value of the Rise Token in specified token
     * @dev This function may revert if _quote token is not configured in Rari
     *      Fuse Price Oracle
     * @param _shares The amount of Rise Token
     * @param _quote The token address used as quote
     * @return _value The net-asset value of the Rise Token in token decimals
     *                precision (ex: USDC is 1e6)
     */
    function value(
        uint256 _shares,
        address _quote
    ) external view returns (uint256 _value);

    /**
     * @notice Gets the net-asset value of the Rise Token in ETH
     * @return _nav The net-asset value of the Rise Token in 1e18 precision
     */
    function nav() external view returns (uint256 _nav);

    /**
     * @notice Gets the leverage ratio of the Rise Token
     * @return _lr Leverage ratio in 1e18 precision
     */
    function leverageRatio() external view returns (uint256 _lr);


    /// ███ User actions ███████████████████████████████████████████████████████

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

}
