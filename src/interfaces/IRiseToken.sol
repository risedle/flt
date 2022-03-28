// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title Rise Token Interface
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
interface IRiseToken is IERC20 {
    function factory() external view returns (address);
    function uniswapAdapter() external view returns (address);
    function oracleAdapter() external view returns (address);
    function collateral() external view returns (address);
    function debt() external view returns (address);
    function fCollateral() external view returns (address);
    function fDebt() external view returns (address);
    function owner() external view returns (address);
    function isInitialized() external view returns (bool);
    function previewInitialize(uint256 _totalCollateralMin, uint256 _nav, uint256 _lr) external view returns (uint256 _ethAmount);
    function initialize(uint256 _collateralMin, uint256 _nav, uint256 _lr) external payable;

    function totalCollateral() external view returns (uint256);
    function totalDebt() external view returns (uint256);
    function nav() external view returns (uint256);
    function leverageRatio() external view returns (uint256);

    // buy & sell
    function previewBuy(uint256 _shares) external view returns (uint256 _ethAmount);
    function previewBuy(uint256 _shares, address _tokenIn) external view returns (uint256 _amountIn);
}
