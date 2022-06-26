// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { RiseToken } from "../src/RiseToken.sol";
import { RiseTokenFactory } from "../src/RiseTokenFactory.sol";
import { IfERC20 } from "../src/interfaces/IfERC20.sol";
import { RariFusePriceOracleAdapter } from "../src/adapters/RariFusePriceOracleAdapter.sol";
import { IUniswapV2Pair } from "../src/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Router02 } from "../src/interfaces/IUniswapV2Router02.sol";

/**
 * @title BNBRISE test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract BNBRISE is Test {

    /// ███ Libraries ████████████████████████████████████████████████████████

    using FixedPointMathLib for uint256;


    /// ███ Storages █████████████████████████████████████████████████████████

    RiseTokenFactory factory = new RiseTokenFactory(vm.addr(1));
    address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    IfERC20 fWBNB = IfERC20(0xFEc2B82337dC69C61195bCF43606f46E9cDD2930);
    IfERC20 fBUSD = IfERC20(0x1f6B34d12301d6bf0b52Db7938Fc90ab4f12fE95);
    address rariOracle = 0xB641c21124546e1c979b4C1EbF13aB00D43Ee8eA;
    RariFusePriceOracleAdapter oracle;

    // PancakeSwap WBNB/BUSD Pair & Router
    IUniswapV2Pair pair = IUniswapV2Pair(0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16);
    IUniswapV2Router02 router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    string name = "BNB 2x Long Risedle";
    string symbol = "BNBRISE";

    function setUp() public {
        oracle = new RariFusePriceOracleAdapter();
        oracle.configure(WBNB, rariOracle, 18);
        oracle.configure(BUSD, rariOracle, 18);
    }

    function deploy() internal returns (RiseToken _riseToken) {
        // Create new Rise Token
        _riseToken = new RiseToken(
            name,
            symbol,
            factory,
            fWBNB,
            fBUSD,
            oracle,
            pair,
            router
        );
    }

    function setBUSDBalance(address _to, uint256 _amount) internal {
        vm.store(
            BUSD,
            keccak256(abi.encode(_to, 1)),
            bytes32(_amount)
        );
    }

    function getInitializationParams(
        uint256 _lr,
        uint256 _totalCollateral,
        uint256 _initialPrice
    ) internal returns (
        uint256 _totalDebt,
        uint256 _amountSend,
        uint256 _shares
    ) {
        address[] memory path = new address[](2);
        path[0] = BUSD;
        path[1] = WBNB;
        uint256 amountIn = router.getAmountsIn(_totalCollateral, path)[0];
        uint256 tcv = oracle.totalValue(
            WBNB,
            BUSD,
            _totalCollateral
        );
        _totalDebt = (tcv.mulWadDown(_lr) - tcv).divWadDown(_lr);
        _amountSend = amountIn - _totalDebt;
        _shares = _amountSend.divWadDown(_initialPrice);
    }

    /// ███ Initialize  ██████████████████████████████████████████████████████

    /// @notice Make sure the transaction revert if non-owner execute
    function testInitializeRevertIfNonOwnerExecute() public {
        // Add supply to Risedle Pool
        uint256 supplyAmount = 100_000_000 * 1e6; // 100M USDC
        setBUSDBalance(address(this), supplyAmount);
        ERC20(BUSD).approve(address(fBUSD), supplyAmount);
        fBUSD.mint(supplyAmount);

        // Deploy Rise Token
        RiseToken riseToken = deploy();
//
//        // Get initialize params
//        uint256 price = 400 * 1e6; // 400 UDSC
//        uint256 ca = 1 * 1e8; // 1 WBTC
//        uint256 lr = 2 ether; // 2x
//        (uint256 da, uint256 send, uint256 shares) = getInitializationParams(
//            lr,
//            ca,
//            price
//        );
//        // Transfer `send` amount to riseToken
//        ERC20(BUSD).transfer(address(riseToken), send);
//
//        // Transfer ownership
//        address newOwner = vm.addr(2);
//        riseToken.transferOwnership(newOwner);
//
//        // Initialize as non owner, this should revert
//        vm.expectRevert("Ownable: caller is not the owner");
//        riseToken.initialize(lr, ca, da, shares);
    }

    /// ███ Mint █████████████████████████████████████████████████████████████


}
