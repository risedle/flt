// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { RariFusePriceOracleAdapter } from "../src/adapters/RariFusePriceOracleAdapter.sol";
import { FLTSinglePair } from "../src/FLTSinglePair.sol";
import { FLTFactory } from "../src/FLTFactory.sol";

import { BaseTest } from "./BaseTest.sol";
import { BaseSinglePair } from "./BaseSinglePair.sol";
import { BaseInitializeTest } from "./BaseInitializeTest.sol";
import { BaseMintTest } from "./BaseMintTest.sol";
import { BaseBurnTest } from "./BaseBurnTest.sol";
import { BaseRebalanceTest } from "./BaseRebalanceTest.sol";
import { BaseRouterTest } from "./BaseRouterTest.sol";
import { BaseRebalancerTest } from "./BaseRebalancerTest.sol";

/**
 * @title BNBDROP test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract BNBDROP is
    BaseTest,
    BaseSinglePair,
    BaseInitializeTest,
    BaseMintTest,
    BaseBurnTest,
    BaseRebalanceTest,
    BaseRouterTest,
    BaseRebalancerTest
{

    /// ███ Storages █████████████████████████████████████████████████████████

    // Risedle Multisig address on Binance
    address multisig = 0x0F12290d070b81B190fAeb07fB65b00882Cc266A;
    address rariOracle = 0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA;

    function getData() internal override returns (Data memory _data) {
        // BUSD as collateral & WBNB as debt
        address collateral = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
        address debt = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

        // Fuse BUSD as collateral and Fuse WBNB as debt
        address fCollateral = 0x1f6B34d12301d6bf0b52Db7938Fc90ab4f12fE95;
        address fDebt = 0xFEc2B82337dC69C61195bCF43606f46E9cDD2930;

        // WBNB/BUSD Pair and router
        address pair = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
        address router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

        RariFusePriceOracleAdapter oracle = new RariFusePriceOracleAdapter();
        oracle.configure(address(collateral), rariOracle, 18);
        oracle.configure(address(debt), rariOracle, 18);

        // Create new factory with multisig as fee recipient
        FLTFactory factory = new FLTFactory(multisig);
        FLTSinglePair implementation = new FLTSinglePair();

        _data = Data({
            // Name & Symbol
            name: "BNB 2x Short Risedle",
            symbol: "BNBDROP",
            deploymentData: abi.encode(fCollateral, fDebt, address(oracle), pair, router),
            implementation: address(implementation),
            factory: factory,

            // Params
            debtSlot: 3,
            collateralSlot: 1,
            totalCollateral: 500 ether, // 500 BUSD
            initialPriceInETH: 0.1 ether, // 0.1 BNB

            // Fuse params
            debtSupplyAmount: 1_000_000 ether // 1M BNB
        });
    }
}
