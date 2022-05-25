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

    /// ███ Types ████████████████████████████████████████████████████████████

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
     * @param collateralAmount The amount of token that will supplied to Rari Fuse
     * @param debtAmount The amount of token that will borrowed from Rari Fuse
     * @param shares The amount of Rise Token to be minted
     * @param fee The amount of Rise Token as fee
     * @param wethAmount The WETH amount from tokenIn
     * @param nav The net-asset value of the Rise Token
     */
    struct BuyParams {
        address buyer;
        address recipient;
        uint256 collateralAmount;
        uint256 debtAmount;
        uint256 shares;
        uint256 fee;
        uint256 wethAmount;
        uint256 nav;
    }

    /**
     * @notice Parameters that used to buy the Rise Token
     * @param seller The msg.sender
     * @param recipient The address that will receive the tokenOut
     * @param collateralAmount The amount of token that will redeemed from Rari Fuse
     * @param debtAmount The amount of token that will repay to Rari Fuse
     * @param shares The amount of Rise Token to be burned
     * @param fee The amount of Rise Token as fee
     * @param nav The net-asset value of the Rise Token
     */
    struct SellParams {
        address seller;
        address recipient;
        uint256 collateralAmount;
        uint256 debtAmount;
        uint256 shares;
        uint256 fee;
        uint256 nav;
    }


    /// ███ Events ███████████████████████████████████████████████████████████

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

    /// ███ Errors ███████████████████████████████████████████████████████████

    /// @notice Error is raised if the caller of onFlashSwapWETHForExactTokens is
    ///         not Uniswap Adapter contract
    error NotUniswapAdapter();

    /// @notice Error is raised if mint amount is invalid
    error InitializeAmountInInvalid();

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
    error SwapAmountTooLarge();

    /// @notice Error is raised if something happen when interacting with Rari Fuse
    error FuseError(uint256 code);

    /// @notice Error is raised if leverage ratio invalid
    error InvalidLeverageRatio();

    /// @notice Error is raised if rebalancing step invalid
    error InvalidRebalancingStep();

    /// @notice Error is raised if discount invalid
    error InvalidDiscount();

    /// @notice Error is raised if flash swap type invalid
    error InvalidFlashSwapType();


    /// ███ Owner actions ████████████████████████████████████████████████████

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


    /// ███ Read-only functions ██████████████████████████████████████████████

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
     * @notice Gets the value of the Rise Token in terms of debt token
     * @param _shares The amount of Rise Token
     * @return _value The value of the Rise Token is terms of debt token
     */
    function value(uint256 _shares) external view returns (uint256 _value);

    /**
     * @notice Gets the net-asset value of the Rise Token in debt token
     * @return _nav The net-asset value of the Rise Token
     */
    function nav() external view returns (uint256 _nav);

    /**
     * @notice Gets the leverage ratio of the Rise Token
     * @return _lr Leverage ratio in 1e18 precision (e.g. 2x is 2*1e18)
     */
    function leverageRatio() external view returns (uint256 _lr);


    /// ███ External functions ███████████████████████████████████████████████

    /**
     * @notice Increase allowance at once
     */
    function increaseAllowance() external;


    /// ███ User actions █████████████████████████████████████████████████████

    /**
     * @notice Buy Rise Token with tokenIn. New Rise Token supply will be minted.
     * @param _shares The amount of Rise Token to buy
     * @param _recipient The recipient of the transaction.
     * @param _tokenIn ERC20 used to buy the Rise Token
     * @return _amountIn The amount of tokenIn used to mint Rise Token
     */
    function buy(
        uint256 _shares,
        address _recipient,
        address _tokenIn,
        uint256 _amountInMax
    ) external payable returns (uint256 _amountIn);

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
    ) external returns (uint256 _amountOut);


    /// ███ Market makers ████████████████████████████████████████████████████

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
     * Market makers can swap collateral (ex: gOHM) to the debt token
     * (ex: USDC) if leverage ratio below minimal Leverage ratio.
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
     * Market makers can swap debt token (ex: USDC) to collateral token
     * (ex: gOHM) if leverage ratio above maximum Leverage ratio.
     *
     * -----------
     *
     * In order to incentives the swap process, Rise Token will give specified
     * discount price 0.6%.
     *
     * push: Market Makers can sell collateral +0.6% above the market price.
     *       For example: suppose the gOHM price is 2000 USDC, when Rise Token
     *       need to increase the leverage ratio, anyone can send 1 gOHM to
     *       Rise Token contract then they will receive 2000 USDC + 12 USDC in
     *       exchange.
     *
     * pull: Market Makers can buy collateral -0.6% below the market price
     *       For example: suppose the gOHM price is 2000 USDC, when Rise Token
     *       need to decrease the leverage ratio, anyone can send 2000 USDC to
     *       Rise Token contract then they will receive 1 gOHM + 0.006 gOHM in
     *       exchange.
     *
     * In this case, market price is determined using Rari Fuse Oracle Adapter.
     *
     * ------------
     * Maximum Swap Amount
     *
     * The maximum swap amount is determined by the rebalancing step.
     *
     * Lr : Leverage ratio after rebalancing
     * L  : Current leverage ratio
     * ΔL : The rebelancing step
     *      ΔL > 0 leveraging up
     *      ΔL < 0 leveraging down
     * V  : Net asset value
     * C  : Current collateral value
     * Cr : Collateral value after rebalancing
     * D  : Current debt value
     * Dr : Debt value after rebalancing
     *
     * The rebalancing process is defined as below:
     *
     *     Lr = L + ΔL ................................................... (1)
     *
     * The leverage ratio is defined as below:
     *
     *     L  = C / V .................................................... (2)
     *     Lr = Cr / Vr .................................................. (3)
     *
     * The net asset value is defined as below:
     *
     *     V  = C - D .................................................... (4)
     *     Vr = Cr - Dr .................................................. (5)
     *
     * The net asset value before and after rebalancing should be equal.
     *
     *     V = Vr ........................................................ (6)
     *
     * Using equation above we got the debt value after rebalancing given ΔL:
     *
     *     Dr = C - D + Cr ............................................... (7)
     *     Dr = D + (ΔL * V) ............................................. (8)
     *
     * So the maximum swap amount is ΔLV.
     *     ΔL > 0 Supply collateral then borrow (swapCollateralForETH)
     *     ΔL < 0 Repay debt and redeem collateral (swapETHForCollateral)
     */

     /**
      * @notice Swaps collateral token (ex: gOHM) for debt token (ex: USDC)
      * @dev Anyone can execute this if leverage ratio is below minimum.
      * @param _amountIn The amount of collateral
      * @return _amountOut The amount of debt token that received by msg.sender
      */
    function push(uint256 _amountIn) external returns (uint256 _amountOut);

     /**
      * @notice Swaps debt token (ex: USDC) for collateral token (ex: gOHM)
      * @dev Anyone can execute this if leverage ratio is below minimum.
      * @param _amountOut The amount of collateral token that will received by
      *        msg.sender
      * @return _amountIn The amount of debt token send by msg.sender
      */
    function pull(uint256 _amountOut) external returns (uint256 _amountIn);

}
