// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { RiseToken } from "../RiseToken.sol";
import { IRiseToken } from "./IRiseToken.sol";

/**
 * @title Rise Token Peripheral Contract Interface
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice Peripheral smart contract for interacting with Rise Token
 */
interface IRiseTokenPeriphery {

    /// ███ Rise Token Initialization ████████████████████████████████████████

    /// @notice Get params to initialize 2x long Rise Token
    /// @param _riseToken The target Rise Token
    /// @param _collateralAmount The initial amount of collateral.
    ///        (e.g. 1 gOHM is 1*1e18)
    /// @param _price The initial price of Rise Token in terms of the debt
    ///        token. (e.g. gOHMRISE with USDC debt is 333 USDC (333 * 1e6))
    function getDefaultParams(
        RiseToken _riseToken,
        uint256 _collateralAmount,
        uint256 _price
    ) external view returns (IRiseToken.InitializeParams memory _params);

    /// @notice Get params to initialize Rise Token with custom leverage ratio
    /// @param _riseToken The target Rise Token
    /// @param _collateralAmount The initial amount of collateral.
    ///        (e.g. 1 gOHM is 1*1e18)
    /// @param _price The initial price of Rise Token in terms of the debt
    ///        token. (e.g. gOHMRISE with USDC debt is 333 USDC (333 * 1e6))
    function getInitializationParams(
        RiseToken _riseToken,
        uint256 _collateralAmount,
        uint256 _price,
        uint256 _lr
    ) external view returns (IRiseToken.InitializeParams memory _params);


    /// ███ Rebalancoooor ████████████████████████████████████████████████████

    /// @notice Get max amount in for leveraging up
    /// @param _riseToken The target Rise Token
    /// @return _maxAmountIn The maximum amount of collateral token
    function getMaxPush(
        RiseToken _riseToken
    ) external returns (uint256 _maxAmountIn);

    /// @notice Preview the push ops
    /// @param _riseToken The target Rise Token
    /// @param _amountIn The collateral token amount
    /// @return _amountOut The debt token amount
    function previewPush(
        RiseToken _riseToken,
        uint256 _amountIn
    ) external returns (uint256 _amountOut);

    /// @notice Get max amount out for leveraging down
    /// @param _riseToken The target Rise Token
    /// @return _maxAmountOut The maximum amount of collateral token
    function getMaxPull(
        RiseToken _riseToken
    ) external returns (uint256 _maxAmountOut);

    /// @notice Preview the pull ops
    /// @param _riseToken The target Rise Token
    /// @param _amountOut The collateral token amount
    /// @return _amountIn The debt token amount
    function previewPull(
        RiseToken _riseToken,
        uint256 _amountOut
    ) external returns (uint256 _amountIn);


    /// ███ Rise Token holders ███████████████████████████████████████████████

    /// @notice Get the amountIn when buying specified shares
    /// @param _riseToken The target Rise Token
    /// @param _tokenIn The address of tokenIn
    /// @param _shares The shares amount
    /// @return _amountIn The amount of tokenIn
    function previewBuy(
        RiseToken _riseToken,
        address _tokenIn,
        uint256 _shares
    ) external view returns (uint256 _amountIn);

    /// @notice Get the amountOut when selling specified shares
    /// @param _riseToken The target Rise Token
    /// @param _tokenOut The address of tokenOut
    /// @param _shares The shares amount
    /// @return _amountOut The amount of tokenOut
    function previewSell(
        RiseToken _riseToken,
        address _tokenOut,
        uint256 _shares
    ) external view returns (uint256 _amountOut);
}
