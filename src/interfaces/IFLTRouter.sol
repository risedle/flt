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

}
