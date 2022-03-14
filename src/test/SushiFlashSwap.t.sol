// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import {IUniswapV2Factory} from "../interface/IUniswapV2Factory.sol";
import {USDC_ADDRESS, GOHM_ADDRESS} from "./Addresses.sol";

contract SushiFlashSwap is DSTest {

    function runFlashSwap() public {
        // Sushiswap Factory
        IUniswapV2Factory factory = IUniswapV2Factory(0xc35DADB65012eC5796536bD9864eD8773aBc74C4);

        // Get pair address
        address pair = factory.getPair(USDC_ADDRESS, GOHM_ADDRESS);

        emit log_named_address("address pair", pair);
    }

    // function callback() public {
    // }
}

contract SushiFlashSwapTest is DSTest {
    function testRunFlashSwap() public {
        SushiFlashSwap flash = new SushiFlashSwap();
        flash.runFlashSwap();
        assert(false);
    }
}