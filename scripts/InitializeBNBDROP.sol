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

contract InitializeBNBDROP is Script, BaseSinglePair {
    using FixedPointMathLib for uint256;
    function getData() internal override returns (Data memory _data) {}

    function run() public {
        vm.startBroadcast();
        address BNBDROP = 0xec448Dcb1FF0A8724EA8cF5c5348d88207d6e9D9;
        address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        uint256 ca = 300 ether; // 300 BUSD
        (uint256 td, uint256 s, uint256 ts) = getInitializationParams(
            BNBDROP,
            ca,
            2 ether,
            0.1 ether
        );
        uint256 slippage = 0.01 ether; // 1%
        uint256 sendAmount = s + slippage.mulWadDown(s);

        // Transfer BUSD to contract
        // ERC20(WBNB).transfer(BNBDROP, s);
        FLT(BNBDROP).initialize(ca, td, ts);
    }
}
