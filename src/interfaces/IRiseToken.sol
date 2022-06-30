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
    enum FlashSwapType { Mint, Burn }

    /// @notice Mint & Burn params
    struct FlashSwapParams {
        FlashSwapType flashSwapType;

        address sender;
        address recipient;
        address refundRecipient;
        ERC20   tokenIn;
        ERC20   tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 feeAmount;
        uint256 refundAmount;
        uint256 borrowAmount;
        uint256 repayAmount;
        uint256 collateralAmount;
        uint256 debtAmount;
    }

    /// ███ Events ███████████████████████████████████████████████████████████

    /// @notice Event emitted when new supply is minted or burned
    event Swap(
        address indexed sender,
        address indexed recipient,
        address indexed tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeAmount,
        uint256 priceInETH
    );

    /**
     * @notice Event emitted when params updated
     * @param maxLeverageRatio The maximum leverage ratio
     * @param minLeverageRatio The minimum leverage ratio
     * @param step The rebalancing step
     * @param discount The incentives for the market makers
     * @param maxMint The maximum amount to mint in one transaction
     */
    event ParamsUpdated(
        uint256 maxLeverageRatio,
        uint256 minLeverageRatio,
        uint256 step,
        uint256 discount,
        uint256 maxMint
    );

    /**
     * @notice Event emitted when the Rise Token is rebalanced
     * @param executor The address who execute the rebalance
     * @param prevLeverageRatio Previous leverage ratio
     * @param leverageRatio Current leverage ratio
     * @param prevTotalCollateral Previous total collateral
     * @param totalCollateral Current total collateral
     * @param prevTotalDebt Previoes total debt
     * @param totalDebt Current total debt
     * @param prevPriceInETH Previous price in ETH
     * @param priceInETH Current price in ETH
     */
    event Rebalanced(
        address executor,
        uint256 prevLeverageRatio,
        uint256 leverageRatio,
        uint256 prevTotalCollateral,
        uint256 totalCollateral,
        uint256 prevTotalDebt,
        uint256 totalDebt,
        uint256 prevPriceInETH,
        uint256 priceInETH
    );

    /// ███ Errors ███████████████████████████████████████████████████████████

    /// @notice Error is raised if the caller is unauthorized
    error Unauthorized();

    /// @notice Error is raised if the owner run the initialize() twice
    error Uninitialized();

    /// @notice Error is raised if rebalance is executed but leverage ratio is invalid
    error Balance();

    /// @notice Error is raised if something happen when interacting with Rari Fuse
    error FuseError(uint256 code);

    /// @notice Errors are raised if params invalid
    error InvalidLeverageRatio();
    error InvalidRebalancingStep();
    error InvalidDiscount();

    /// @notice Errors are raised if flash swap is invalid
    error InvalidFlashSwapType();
    error InvalidFlashSwapAmount();

    /// @notice Errors are raised if amountIn or amountOut is invalid
    error AmountInTooLow();
    error AmountOutTooLow();
    error AmountOutTooHigh();


    /// ███ Owner actions ████████████████████████████████████████████████████

    /**
     * @notice Update the Rise Token parameters
     * @param _minLeverageRatio Minimum leverage ratio
     * @param _maxLeverageRatio Maximum leverage ratio
     * @param _step Rebalancing step
     * @param _discount Discount for market makers to incentivize the rebalance
     * @param _maxMint Maximum mint amount
     */
    function setParams(
        uint256 _minLeverageRatio,
        uint256 _maxLeverageRatio,
        uint256 _step,
        uint256 _discount,
        uint256 _maxMint
    ) external;

    /**
     * @notice Initialize the Rise Token using debt token
     * @dev Owner must send enough debt token to the rise token contract  in
     *      order to initialize the Rise Token.
     *
     *      Required amount is defined below:
     *
     *          Given:
     *            - lr: Leverage Ratio
     *            - ca: Collateral Amount
     *            - p : Initial Price
     *
     *          Steps:
     *            1. Get `amountIn` to swap `ca` amount of collateral via
     *               uniswap v2 router.
     *            2. tcv = ca * collateral price (via oracle.totalValue)
     *            3. td = ((lr*tcv)-tcv)/lr
     *            4. amountSend = amountIn - td
     *            5. shares = amountSend / initialPrice
     *
     *          Outputs: td (Total debt), amountSend & shares
     *
     * @param _ca Initial total collateral
     * @param _da Initial total debt
     * @param _shares Initial supply of Rise Token
     */
    function initialize(uint256 _ca, uint256 _da, uint256 _shares) external;


    /// ███ Read-only functions ██████████████████████████████████████████████

    /**
     * @notice Gets the collateral and debt amount give the shares amount
     * @param _amount The shares amount
     * @return _ca Collateral amount (ex: gOHM is 1e18 precision)
     * @return _da Debt amount (ex: USDC is 1e6 precision)
     */
    function sharesToUnderlying(
        uint256 _amount
    ) external view returns (uint256 _ca, uint256 _da);

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
     * @notice Gets the latest price of the Rise Token in ETH base units
     * @return _price The latest price of the Rise Token
     */
    function price() external view returns (uint256 _price);

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
     * @notice Mint Rise Token using debt token
     * @dev This is low-level call for minting new supply of Rise Token.
     *      This function only expect the exact amount of debt token available
     *      owned by this contract at the time of minting. Otherwise the
     *      minting process will be failed.
     *
     *      This function should be called via high-level conctract such as
     *      router that dealing with swaping any token to exact amount
     *      of debt token.
     * @param _shares The amount of Rise Token to mint
     * @param _recipient The recipient of Rise Token
     * @param _refundRecipient The recipient of unused debt token
     */
    function mintd(
        uint256 _shares,
        address _recipient,
        address _refundRecipient
    ) external;

    /**
     * @notice Mint Rise Token using collateral token
     * @dev This is low-level call for minting new supply of Rise Token.
     *      This function only expect the exact amount of collateral token
     *      available owned by this contract at the time of minting. Otherwise
     *      the minting process will be failed.
     *
     *      This function should be called via high-level conctract such as
     *      router that dealing with swaping any token to exact amount
     *      of debt token.
     * @param _shares The amount of Rise Token to mint
     * @param _recipient The recipient of Rise Token
     * @param _refundRecipient The recipient of unused collateral token
     */
    function mintc(
        uint256 _shares,
        address _recipient,
        address _refundRecipient
    ) external;

    /**
     * @notice Burn Rise Token to debt token
     * @dev This is low-level call for burning new supply of Rise Token in
     *      order to get minAmountOut of debt token.
     *      This function expect the exact amount of Rise Token owned by this
     *      contract. Otherwise the function will revert.
     * @param _recipient The recipient of debt token
     * @param _minAmountOut The minimum amount of debt token
     */
    function burnd(address _recipient, uint256 _minAmountOut) external;

    /**
     * @notice Burn Rise Token to collateral token
     * @dev This is low-level call for burning new supply of Rise Token in
     *      order to get minAmountOut of collateral token.
     *      This function expect the exact amount of Rise Token owned by this
     *      contract. Otherwise the function will revert.
     * @param _recipient The recipient of collateral token
     * @param _minAmountOut The minimum amount of collateral token
     */
    function burnc(address _recipient, uint256 _minAmountOut) external;


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
