// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

import { RiseTokenFactory } from "../src/RiseTokenFactory.sol";
import { IfERC20 } from "../src/interfaces/IfERC20.sol";
import { RariFusePriceOracleAdapter } from "../src/adapters/RariFusePriceOracleAdapter.sol";
import { IUniswapV2Pair } from "../src/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Router02 } from "../src/interfaces/IUniswapV2Router02.sol";

import { BaseTest } from "./BaseTest.sol";

/**
 * @title BNBRISE test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract BNBRISE is BaseTest {

    /// ███ Storages █████████████████████████████████████████████████████████

    // Risedle Multisig address on Binance
    address multisig = 0x0F12290d070b81B190fAeb07fB65b00882Cc266A;
    address rariOracle = 0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA;
    Data data;

    function setUp() public {
        // WBNB as collateral & BUSD as debt
        ERC20 collateral = ERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
        ERC20 debt = ERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);

        RiseTokenFactory factory = new RiseTokenFactory(multisig);

        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();
        oracle.configure(address(collateral), rariOracle, 18);
        oracle.configure(address(debt), rariOracle, 18);

        data = Data({
            // Factory
            factory: factory,

            // Name & Symbol
            name: "BNB 2x Long Risedle",
            symbol: "BNBRISE",

            collateral: collateral,
            debt: debt,

            // Fuse WBNB as collateral and Fuse BUSD as debt
            fCollateral: IfERC20(0xFEc2B82337dC69C61195bCF43606f46E9cDD2930),
            fDebt: IfERC20(0x1f6B34d12301d6bf0b52Db7938Fc90ab4f12fE95),
            oracle: oracle,

            // WBNB/BUSD Pair and router
            pair: IUniswapV2Pair(0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16),
            router: IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E),

            // Params
            debtSlot: 1,
            totalCollateral: 3 ether, // 3 BNB
            initialPriceInETH: 0.3 ether, // 0.3 BNB

            // Fuse params
            debtSupplyAmount: 1_000_000 ether // 1M BUSD
        });
    }


    /// ███ Initialize  ██████████████████████████████████████████████████████

    function testInitializeRevertIfNonOwnerExecute() public {
        _testInitializeRevertIfNonOwnerExecute(data);
    }

    function testInitializeRevertIfNoTransfer() public {
        _testInitializeRevertIfNoTransfer(data);
    }

    function testPancakeCallRevertIfCallerIsNotPair() public {
        _testPancakeCallRevertIfCallerIsNotPair(data);
    }

    function testUniswapV2CallRevertIfCallerIsNotPair() public {
        _testUniswapV2CallRevertIfCallerIsNotPair(data);
    }

    function testInitializeWithLeverageRatio2x() public {
        _testInitializeWithLeverageRatio2x(data);
    }

    /// ███ Mint █████████████████████████████████████████████████████████████


}
