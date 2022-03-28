// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

/**
 * @title Uniswap V3 Pool Interface
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
interface IUniswapV3Pool {
    /// @notice Docs: https://docs.uniswap.org/protocol/reference/core/UniswapV3Pool#swap
    function swap(address _recipient, bool _zeroForOne, int256 _amountSpecified, uint160 _sqrtPriceLimitX96, bytes memory _data) external returns (int256 amount0, int256 amount1);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
}
