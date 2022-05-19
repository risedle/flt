// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IVM } from "./IVM.sol";
import { VMUtils } from "./VMUtils.sol";

import { UniswapAdapter } from "../adapters/UniswapAdapter.sol";
import { IUniswapAdapter } from "../interfaces/IUniswapAdapter.sol";
import { RariFusePriceOracleAdapter } from "../adapters/RariFusePriceOracleAdapter.sol";
import { RiseTokenFactory } from "../RiseTokenFactory.sol";
import { RiseToken } from "../RiseToken.sol";
import { IRiseToken } from "../interfaces/IRiseToken.sol";
import { RiseTokenPeriphery } from "../RiseTokenPeriphery.sol";

import { weth, usdc, wbtc } from "chain/Tokens.sol";
import { fusdc, fwbtc } from "chain/Tokens.sol";
import { uniswapV3USDCETHPool, uniswapV3Router, uniswapV3WBTCETHPool } from "chain/Tokens.sol";
import { rariFuseUSDCPriceOracle, rariFuseWBTCPriceOracle } from "chain/Tokens.sol";

/**
 * @title Rise Token Testing Utilities
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract RiseTokenUtils {

    /// ███ Storages █████████████████████████████████████████████████████████

    IVM private immutable vm = IVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    VMUtils                    private utils;
    RiseTokenPeriphery         private periphery;
    UniswapAdapter             public  uniswapAdapter;
    RariFusePriceOracleAdapter public  oracleAdapter;


    /// ███ ETH Transfer █████████████████████████████████████████████████████

    /// @notice Receives ETH
    receive() external payable {
        // We need this in order to recieve ETH refund after Rise Token
        // initialization process
    }


    /// ███ Constructor ██████████████████████████████████████████████████████

    constructor() {
        // Create utils
        utils = new VMUtils(vm);

        // Create periphery
        periphery = new RiseTokenPeriphery();

        // Create uniswap adapter
        uniswapAdapter = new UniswapAdapter(weth);
        uniswapAdapter.configure(
            wbtc,
            IUniswapAdapter.UniswapVersion.UniswapV3,
            uniswapV3WBTCETHPool,
            uniswapV3Router
        );
        uniswapAdapter.configure(
            usdc,
            IUniswapAdapter.UniswapVersion.UniswapV3,
            uniswapV3USDCETHPool,
            uniswapV3Router
        );

        // Create price oracle
        oracleAdapter = new RariFusePriceOracleAdapter();
        oracleAdapter.configure(wbtc, rariFuseWBTCPriceOracle, 8);
        oracleAdapter.configure(usdc, rariFuseUSDCPriceOracle, 6);
    }


    /// ███ Utilities ████████████████████████████████████████████████████████

    /// @notice Create new Rise Token
    function createWBTCRISE() external returns (RiseToken _wbtcRise) {
        // Create factory
        address feeRecipient = vm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new Rise token
        _wbtcRise = factory.create(
            fwbtc,
            fusdc,
            uniswapAdapter,
            oracleAdapter
        );

        // Add supply to the Rari Fuse
        uint256 supplyAmount = 100_000_000 * 1e6; // 100M USDC
        utils.setUSDCBalance(address(this), supplyAmount);
        _wbtcRise.debt().approve(address(fusdc), supplyAmount);
        fusdc.mint(supplyAmount);
    }

    /// @notice Initialize Rise Token with custom leverage ratio
    function initializeWBTCRISE(
        RiseToken _wbtcRise,
        uint256 _lr
    ) external payable {
        // Initialize WBTCRISE
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC

        IRiseToken.InitializeParams memory params;
        params = periphery.getInitializationParams(
            _wbtcRise,
            collateralAmount,
            price,
            _lr
        );
        _wbtcRise.initialize{value: msg.value}(params);
    }

    /// @notice Set max buy
    function setMaxBuy(RiseToken _wbtcRise, uint256 _amount) external {
        _wbtcRise.setParams(
            _wbtcRise.minLeverageRatio(),
            _wbtcRise.maxLeverageRatio(),
            _wbtcRise.step(),
            _wbtcRise.discount(),
            _amount
        );
    }

}

