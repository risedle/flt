// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";
import "forge-std/Script.sol";
import { BaseSinglePair } from "../test/BaseSinglePair.sol";

interface FLT {
    function initialize(
        uint256 _ca,
        uint256 _da,
        uint256 _shares
    ) external;
}

interface ERC20 {
    function transfer(address to, uint256 amount) external;
}

contract InitializeBNBRISE is Script, BaseSinglePair {
    using FixedPointMathLib for uint256;
    function getData() internal override returns (Data memory _data) {}

    function run() public {
        vm.startBroadcast();
        address BNBRISE = 0x4f7255178b8f15c2CbE92d09b8A77b53ef4eC9Ea;
        address BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
        uint256 ca = 3 ether; // 3 BNB
        (uint256 td, uint256 s, uint256 ts) = getInitializationParams(
            BNBRISE,
            ca,
            2 ether,
            0.1 ether
        );
        uint256 slippage = 0.01 ether; // 1%
        uint256 sendAmount = s + slippage.mulWadDown(s);

        // Transfer BUSD to contract
        ERC20(BUSD).transfer(BNBRISE, s);
        FLT(BNBRISE).initialize(ca, td, ts);
    }
}
