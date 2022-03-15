// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "../interfaces/IUniswapV2Pair.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {GOHM_ADDRESS} from "./Addresses.sol";
import { HEVM } from "./HEVM.sol";

contract SushiFlashSwap is DSTest {

    IUniswapV2Router02 private router;
    IUniswapV2Factory private factory;
    address private WETH;

    constructor() {
        // Sushiswap router
        router = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
        // Sushiswap Factory
        factory = IUniswapV2Factory(router.factory());
        // WETH
        WETH = router.WETH();
    }

    function runFlashSwap() public {
        // Get pair address
        address pairAddress = factory.getPair(GOHM_ADDRESS, WETH);
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
        bytes memory data = abi.encode(borrowAmount);

        // Perform the flashswap
        IUniswapV2Pair(pairAddress).swap(amount0Out, amount1Out, address(this), data);

    }

    error NotAuthorized(address caller);

    // @notice Function is called by the Uniswap V2 pair's `swap` function
    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes calldata _data) external {
        // Checks
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        if(msg.sender != factory.getPair(token0, token1)) revert NotAuthorized(msg.sender);
        if(_sender != address(this)) revert NotAuthorized(_sender);

        // Effects
        uint256 borrowAmount = abi.decode(_data, (uint256));
        uint256 fee = ((borrowAmount * 3) / 997) + 1;
        uint256 repayAmount = borrowAmount + fee;

        // Interaction
        uint256 balance = IERC20(GOHM_ADDRESS).balanceOf(address(this));
        emit log_named_uint("_amount0", _amount0);
        emit log_named_uint("_amount1", _amount1);
        emit log_named_uint("balance", balance);
        emit log_named_uint("repayAmount", repayAmount);

        //
    }
}

contract SushiFlashSwapTest is DSTest {
    HEVM internal hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    function testRunFlashSwap() public {
        SushiFlashSwap flash = new SushiFlashSwap();
        // Set USDC balance for the flashswap

        flash.runFlashSwap();
        assert(false);
    }
}