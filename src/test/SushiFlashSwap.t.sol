// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import {IUniswapV2Factory} from "../interface/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "../interface/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "../interface/IUniswapV2Pair.sol";
import {GOHM_ADDRESS} from "./Addresses.sol";

contract SushiFlashSwap is DSTest {

    function runFlashSwap() public {
        // Sushiswap router
        IUniswapV2Router02 router = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
        // Sushiswap Factory
        IUniswapV2Factory factory = IUniswapV2Factory(router.factory());
        // WETH
        address WETH_ADDRESS = router.WETH();
        // Get pair address
        address pairAddress = factory.getPair(GOHM_ADDRESS, WETH_ADDRESS);
        // Get pair
        IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);

        // Get address for each token
        address token0 = pair.token0();
        address token1 = pair.token1();

        // Perform flash swap
        emit log_named_address("token0", token0);
        emit log_named_address("token1", token1);

        // Decide the amount
        uint256 borrowAmount = 1 ether; // 1 gOHM
        address borrowToken = GOHM_ADDRESS;
        uint256 amount0Out = borrowToken == token0 ? borrowAmount : 0;
        uint256 amount1Out = borrowToken == token1 ? borrowAmount : 0;
        bytes memory data = abi.encode(borrowAmount, borrowToken);

        // Perform the flashswap
        IUniswapV2Pair(pairAddress).swap(amount0Out, amount1Out, address(this), data);

    }

    // @notice Function is called by the Uniswap V2 pair's `swap` function
    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        emit log_named_address("sender", _sender);
    }
}

contract SushiFlashSwapTest is DSTest {
    function testRunFlashSwap() public {
        SushiFlashSwap flash = new SushiFlashSwap();
        flash.runFlashSwap();
        assert(false);
    }
}