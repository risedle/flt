// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;
pragma experimental ABIEncoderV2;

import "lib/ds-test/src/test.sol";

import { IUniswapV2Factory } from "../interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Router02 } from "../interfaces/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "../interfaces/IUniswapV2Pair.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { GOHM_ADDRESS, USDC_ADDRESS } from "./Addresses.sol";
import { HEVM } from "./HEVM.sol";

/**
 * @title Sushi Flash Swap
 * @author bayu (github.com/pyk)
 * @notice This contract is used to test-out the triangular flashswap.
 *         Triangular flashswap is flash swap to borrow A token and repay it
 *         with B token using 2 pairs of liquidity: A/ETH and B/ETH.
 *
 *         Step by step of to borrow A and repay with B:
 *         1. Given A/ETH and B/ETH liquidity pairs
 *         2. Calculate how many `n` ETH needed to get `x` amount of A token.
 *         3. Borrow `n` ETH from B/ETH liquidity pair.
 *         4. Swap `n` ETH to `x` A token via A/ETH liquidity pair.
 *         5. `x` amount of A token is acquired.
 *         6. Calculate how many `y` B token needed to get `n` ETH.
 *         7. Send `y` B token to B/ETH liquidity pair repay the flash loan.
 *         8. DONE
 */
contract SushiFlashSwap is DSTest {
    /// ███ Libraries ██████████████████████████████████████████████████████████
    using SafeERC20 for IERC20;


    /// ███ Storages ███████████████████████████████████████████████████████████
    IUniswapV2Router02 private router;
    IUniswapV2Factory private factory;
    address private WETH;
    address private gohmPairAddress;
    address private usdcPairAddress;

    /// ███ Errors █████████████████████████████████████████████████████████████
    error NotAuthorized(address caller);

    constructor() {
        // Sushiswap router
        router = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
        // Sushiswap Factory
        factory = IUniswapV2Factory(router.factory());
        // WETH
        WETH = router.WETH();

        // Get gOHM/WETH and USDC/WETH pair addresses
        gohmPairAddress = factory.getPair(GOHM_ADDRESS, WETH);
        usdcPairAddress = factory.getPair(USDC_ADDRESS, WETH);
    }

    function runFlashSwap() public {
        // Decide how much gOHM we want to borrow
        uint256 gohmAmount = 1 ether; // 1 gOHM

        // Calculate how much WETH we need to borrow from USDC/WETH pool
        // to get x amount of gOHM
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = GOHM_ADDRESS;
        uint256 wethAmount = router.getAmountsIn(gohmAmount, path)[0];
        emit log_named_uint("wethAmount", wethAmount);

        // Borrow WETH from USDC/WETH pool
        address token0 = IUniswapV2Pair(usdcPairAddress).token0();
        address token1 = IUniswapV2Pair(usdcPairAddress).token1();
        uint256 amount0Out = WETH == token0 ? wethAmount : 0;
        uint256 amount1Out = WETH == token1 ? wethAmount : 0;

        // Perform the flashswap
        bytes memory data = abi.encode(gohmAmount);
        IUniswapV2Pair(usdcPairAddress).swap(amount0Out, amount1Out, address(this), data);
    }

    // @notice Function is called by the Uniswap V2 pair's `swap` function
    function uniswapV2Call(address _sender, uint256 _amount0, uint256 _amount1, bytes memory _data) external {
        /**
         * Checks
         */
        if (msg.sender != usdcPairAddress) revert NotAuthorized(msg.sender);
        if (_sender != address(this)) revert NotAuthorized(_sender);

        /**
         * Effects
         */

        /**
         * Interactions
         */

        // Get weth amount and gOHM amount
        uint256 wethAmount = _amount0 == 0 ? _amount1 : _amount0;
        uint256 gohmAmount = abi.decode(_data, (uint256));

        // Swap WETH to the gOHM
        address token0 = IUniswapV2Pair(gohmPairAddress).token0();
        address token1 = IUniswapV2Pair(gohmPairAddress).token1();
        uint256 amount0Out = GOHM_ADDRESS == token0 ? gohmAmount : 0;
        uint256 amount1Out = GOHM_ADDRESS == token1 ? gohmAmount : 0;
        IERC20(WETH).safeTransfer(gohmPairAddress, wethAmount);
        IUniswapV2Pair(gohmPairAddress).swap(amount0Out, amount1Out, address(this), bytes(""));

        // Calculate how much USDC we need to repay to USDC/WETH pool given
        // y amount of WETH
        address[] memory path = new address[](2);
        path[0] = USDC_ADDRESS;
        path[1] = WETH;
        uint256 usdcAmount = router.getAmountsIn(wethAmount, path)[0];
        emit log_named_uint("usdcAmount", usdcAmount);

        // Repay the USDC
        IERC20(USDC_ADDRESS).safeTransfer(usdcPairAddress, usdcAmount);
    }
}

/**
 * @title Sushi Flash Swap Test
 * @author bayu (github.com/pyk)
 * @notice Smart contract for trying the Sushi flash-swap.
 */
contract SushiFlashSwapTest is DSTest {
    HEVM internal hevm;

    function setUp() public {
        hevm = new HEVM();
    }

    function testRunFlashSwap() public {
        SushiFlashSwap flash = new SushiFlashSwap();
        // Set USDC balance for the flashswap
        hevm.setUSDCBalance(address(flash), 10_000 * 1e6); // 10K USDC
        flash.runFlashSwap();
        uint256 gohmBalance = IERC20(GOHM_ADDRESS).balanceOf(address(flash));
        uint256 usdcBalance = IERC20(USDC_ADDRESS).balanceOf(address(flash));

        emit log_named_uint("gohmBalance", gohmBalance);
        emit log_named_uint("usdcBalance", usdcBalance);

        // Uncomment this to see the logs
        // assertEq(gohmBalance, usdcBalance);
    }
}
