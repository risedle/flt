// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";

import { IfERC20 } from "./IfERC20.sol";

import { RariFusePriceOracleAdapter } from "../adapters/RariFusePriceOracleAdapter.sol";
import { FLTFactory } from "../FLTFactory.sol";

/**
 * @title Fuse Leveraged Token Interface
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @dev Optimized version of RiseToken to work with single or multi-pair
 */
interface IFLT {

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

    event ParamsUpdated(
        uint256 maxLeverageRatio,
        uint256 minLeverageRatio,
        uint256 maxDrift,
        uint256 maxIncentive,
        uint256 maxSupply
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

    /// @notice Error is raised if contract is deployed twice
    error Deployed();

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
    error InvalidMaxDrift();
    error InvalidMaxIncentive();

    /// @notice Errors are raised if flash swap is invalid
    error InvalidFlashSwapType();
    error InvalidFlashSwapAmount();

    /// @notice Errors are raised if amountIn or amountOut is invalid
    error AmountInTooLow();
    error AmountOutTooLow();
    error AmountOutTooHigh();


    /// ███ Owner actions ████████████████████████████████████████████████████

    /**
     * @notice Update the FLT parameters
     * @param _minLeverageRatio Minimum leverage ratio
     * @param _maxLeverageRatio Maximum leverage ratio
     * @param _maxDrift Maximum leverage ratio drift from min and max
     * @param _maxIncentive Maximum incentive to rebalance the token
     * @param _maxSupply Maximum total supply of FLT
     */
    function setParams(
        uint256 _minLeverageRatio,
        uint256 _maxLeverageRatio,
        uint256 _maxDrift,
        uint256 _maxIncentive,
        uint256 _maxSupply
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

    /// @notice storages
    function factory() external view returns (FLTFactory);
    function debt() external view returns (ERC20);
    function collateral() external view returns (ERC20);
    function fDebt() external view returns (IfERC20);
    function fCollateral() external view returns (IfERC20);
    function oracleAdapter() external view returns (RariFusePriceOracleAdapter);

    function totalCollateral() external view returns (uint256);
    function totalDebt() external view returns (uint256);

    function minLeverageRatio() external view returns (uint256);
    function maxLeverageRatio() external view returns (uint256);
    function maxDrift() external view returns (uint256);
    function maxIncentive() external view returns (uint256);
    function maxSupply() external view returns (uint256);
    function fees() external view returns (uint256);

    function isInitialized() external view returns (bool);

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
     * @notice Deploy this contract
     * @dev Can be deployed once per clone
     */
    function deploy(
        address _factory,
        string memory _name,
        string memory _symbol,
        bytes  memory _data
    ) external;

    /**
     * @notice Increase allowance at once
     */
    function increaseAllowance() external;

    /// @notice callbacks
    function uniswapV2Call(address,uint256,uint256,bytes memory) external;
    function pancakeCall(address,uint256,uint256,bytes memory) external;


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
     * FLT is designed in such way that users get protection against
     * liquidation, while market makers are well-incentivized to execute the
     * rebalancing process.
     *
     * ===== Leveraging Up
     * When collateral (ex: gOHM) price is going up, the net-asset value of
     * Fuse Leveraged Token (ex: gOHMRISE) will going up and the leverage
     * ratio will going down.
     *
     * If leverage ratio is below specified minimum leverage ratio (ex: 1.7x),
     * Fuse Leveraged Token need to borrow more asset from Fuse (ex: USDC),
     * in order to buy more collateral then supply the collateral to Rari Fuse.
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
     * Fuse Leveraged Token (ex: gOHMRISE) will going down and the leverage
     * ratio  will going up.
     *
     * If leverage ratio is above specified maximum leverage ratio (ex: 2.3x),
     * Fuse Leveraged Token need to sell collateral in order to repay debt to
     * Fuse.
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
     * Anyone is incentivized to execute the rebalance. The maximum incentive
     * is set to 20%. FLT leverages a Dutch-auction style mechanism which
     * allows the market to express itself in determining what the appropriate
     * rebalancing incentive needs to be.
     *
     * The further away a FLT's leverage ratio drifts below min leverage ratio
     * or max leverage ratio, the larger the rebalancing incentive becomes.
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
     *     ΔL > 0 Supply collateral then borrow
     *     ΔL < 0 Repay debt and redeem collateral
     */

    /**
     * @notice Push the leverage ratio up by sending collateral token to
     *         contract.
     * @dev Anyone can execute this if leverage ratio is below minimum.
     */
    function pushc()
        external
        returns (uint256 _amountOut, uint256 _incentiveAmount);

     /**
      * @notice Push the leverage ratio down by sending debt token to contract.
      * @dev Anyone can execute this if leverage ratio is below minimum.
      */
    function pushd() external;

}
