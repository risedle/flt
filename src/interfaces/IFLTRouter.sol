// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title FLT Router Interface
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice User-friendly contract to swap FLT tokens
 */
interface IFLTRouter {

    /// ███ Errors ███████████████████████████████████████████████████████████

    /// @notice Errors are raised if ERC20 address is invalid
    error InvalidTokenIn();
    error InvalidTokenOut();
    error InvalidFLT();


    /// ███ Externals ████████████████████████████████████████████████████████

    /**
     * @notice Given the amount of FLT, get the amountIn required to mint
     * @param _flt FLT token
     * @param _tokenIn Input token address
     * @param _amountOut The amount of FLT token to mint
     * @return _amountIn The required amount of tokenIn to mint amountOut of FLT
     */
    function getAmountIn(
        address _flt,
        address _tokenIn,
        uint256 _amountOut
    ) external returns (uint256 _amountIn);

    /**
     * @notice Given the amount of FLT, get the amountOut of tokenOut
     * @param _flt FLT token
     * @param _tokenOut Output token address
     * @param _amountIn The amount of FLT token to burn
     * @return _amountOut The amount of tokenOut when burning amountIn of FLT
     */
    function getAmountOut(
        address _flt,
        address _tokenOut,
        uint256 _amountIn
    ) external returns (uint256 _amountOut);

    /**
     * @notice Swap tokens for exact amount of FLT
     * @param _tokenIn ERC20 address (debt / collateral token)
     * @param _maxAmountIn Maximum amount of tokenIn
     * @param _flt The FLT address
     * @param _amountOut The exact amount of FLT
     */
    function swapTokensForExactFLT(
        address _tokenIn,
        uint256 _maxAmountIn,
        address _flt,
        uint256 _amountOut
    ) external;

}
