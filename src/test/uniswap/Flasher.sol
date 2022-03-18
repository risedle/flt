// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import { IUniswapAdapter } from "../../interfaces/IUniswapAdapter.sol";

/**
 * @title Flasher
 * @author bayu (github.com/pyk)
 * @notice Contract to simulate the flash swap user of UniswapV2Adapter.
 *         This contract implements IFlashSwapper.
 */
contract Flasher {
    /// ███ Libraries ██████████████████████████████████████████████████████████
    using SafeERC20 for IERC20;


    /// ███ Storages ███████████████████████████████████████████████████████████

    /// @notice Uniswap V2 Adapter
    address private uniswapAdapter;


    /// ███ Errors █████████████████████████████████████████████████████████████

    error NotUniswapAdapter();


    /// ███ Constructors ███████████████████████████████████████████████████████

    constructor(address _uniswapAdapter) {
        uniswapAdapter = _uniswapAdapter;
    }


    /// ███ External functions █████████████████████████████████████████████████

    /// @notice Trigger the flash swap
    function trigger(address _borrowToken, uint256 _amount, address _repayToken) external {
        IUniswapAdapter(uniswapAdapter).flash(_borrowToken, _amount, _repayToken);
    }

    /// @notice Executed by the adapter
    function onFlashSwap(address _borrowToken, uint256 _borrowAmount, address _repayToken, uint256 _repayAmount) external {
        if (msg.sender != uniswapAdapter) revert NotUniswapAdapter();

        // Repay the token
        IERC20(_repayToken).safeTransfer(uniswapAdapter, _repayAmount);
    }
}
