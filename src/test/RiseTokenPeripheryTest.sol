// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { IVM } from "./IVM.sol";
import { VMUtils } from "./VMUtils.sol";

import { RiseTokenPeriphery } from "../RiseTokenPeriphery.sol";
import { RiseToken } from "../RiseToken.sol";
import { IRiseToken } from "../interfaces/IRiseToken.sol";
import { RiseTokenFactory } from "../RiseTokenFactory.sol";
import { UniswapAdapter } from "../adapters/UniswapAdapter.sol";
import { IUniswapAdapter } from "../interfaces/IUniswapAdapter.sol";
import { RariFusePriceOracleAdapter } from "../adapters/RariFusePriceOracleAdapter.sol";
import { IfERC20 } from "../interfaces/IfERC20.sol";

import { weth, usdc, wbtc } from "chain/Tokens.sol";
import { fusdc, fwbtc } from "chain/Tokens.sol";
import { rariFuseUSDCPriceOracle, rariFuseWBTCPriceOracle } from "chain/Tokens.sol";
import { uniswapV3USDCETHPool, uniswapV3Router, uniswapV3WBTCETHPool } from "chain/Tokens.sol";

/**
 * @title Rise Token Peripheral Contract Test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract RiseTokenPeripheryTest {

    /// ███ Libraries ████████████████████████████████████████████████████████

    using FixedPointMathLib for uint256;


    /// ███ Storages █████████████████████████████████████████████████████████

    IVM private immutable vm = IVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    VMUtils                    private utils;
    RiseTokenPeriphery         private periphery;
    UniswapAdapter             private uniswapAdapter;
    RariFusePriceOracleAdapter private oracleAdapter;

    event Debug(string msg, uint256 value);


    /// ███ ETH Transfer Callback ████████████████████████████████████████████

    /// @notice This function is executed when this contract receives ETH
    receive() external payable {
        // We need this in order to receive ETH refund when initializing the
        // Rise Token
    }


    /// ███ Test Setup ███████████████████████████████████████████████████████

    function setUp() public {
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

    /// @notice deploy and initialize Rise Token
    /// @param _collateralAmount The initial total collateral
    /// @param _price The initial price in debt token precision (ex: 100 USDC is 100 * 1e6)
    /// @param _lr The target leverage ratio
    function createRiseToken(
        uint256 _collateralAmount,
        uint256 _price,
        uint256 _lr
    ) public returns (
        RiseToken _riseToken,
        IRiseToken.InitializeParams memory _params
    ) {
        // Create Rise Token
        address feeRecipient = vm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new Rise token
        _riseToken = factory.create(
            fwbtc,
            fusdc,
            uniswapAdapter,
            oracleAdapter
        );

        // Add supply to the Rari Fuse
        uint256 supplyAmount = 100_000_000 * 1e6; // 100M USDC
        utils.setUSDCBalance(address(this), supplyAmount);
        _riseToken.debt().approve(address(fusdc), supplyAmount);
        fusdc.mint(supplyAmount);

        // Initialize WBTCRISE
        _params = periphery.getInitializationParams(
            _riseToken,
            _collateralAmount,
            _price,
            _lr
        );
        _params.ethAmount = 10 ether;
        uint256 prevBalance = address(this).balance;
        _riseToken.initialize{value: _params.ethAmount}(_params);

        // Check refund
        require(address(this).balance > prevBalance - 10 ether, "no refund");
    }


    /// ███ Test Initialization Params ███████████████████████████████████████

    /// @notice Test to get 2x initialization params
    function testGetInitializationParamsEqualTo2x() public {
        // Create new Rise token
        uint256 lr = 2 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        IRiseToken.InitializeParams memory params;
        (wbtcRise, params) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        // Check storages
        require(wbtcRise.totalSupply() == params.shares, "invalid shares");
        require(wbtcRise.leverageRatio() > (lr - 0.001 ether), "invalid leverage ratio");
        require(wbtcRise.leverageRatio() < (lr + 0.001 ether), "invalid leverage ratio");
        require(wbtcRise.totalCollateral() == collateralAmount, "invalid total collateral");
        require(wbtcRise.totalDebt() == params.borrowAmount, "invalid borrow amount");
        require(wbtcRise.nav() > price - (0.1*1e6), "invalid price");
        require(wbtcRise.nav() < price + (0.1*1e6), "invalid price");
    }

    /// @notice Test to get 1.6x initialization params
    function testGetInitializationParamsLessThan2x() public {
        // Create new Rise token
        uint256 lr = 1.6 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        IRiseToken.InitializeParams memory params;
        (wbtcRise, params) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        // Check storages
        require(wbtcRise.totalSupply() == params.shares, "invalid shares");
        require(wbtcRise.leverageRatio() > (lr - 0.001 ether), "invalid leverage ratio");
        require(wbtcRise.leverageRatio() < (lr + 0.001 ether), "invalid leverage ratio");
        require(wbtcRise.totalCollateral() < collateralAmount, "invalid total collateral");
        require(wbtcRise.totalDebt() == params.borrowAmount, "invalid borrow amount");
        require(wbtcRise.nav() > price - (0.1*1e6), "invalid price");
        require(wbtcRise.nav() < price + (0.1*1e6), "invalid price");
    }

    /// @notice Test to get 2.5x initialization params
    function testGetInitializationParamsGreaterThan2x() public {
        // Create new Rise token
        uint256 lr = 2.8 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        IRiseToken.InitializeParams memory params;
        (wbtcRise, params) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        // Check storages
        require(wbtcRise.totalSupply() == params.shares, "invalid shares");
        require(wbtcRise.leverageRatio() > (lr - 0.001 ether), "invalid leverage ratio");
        require(wbtcRise.leverageRatio() < (lr + 0.001 ether), "invalid leverage ratio");
        require(wbtcRise.totalCollateral() > collateralAmount, "invalid total collateral");
        require(wbtcRise.totalDebt() == params.borrowAmount, "invalid borrow amount");
        require(wbtcRise.nav() > price - (0.1*1e6), "invalid price");
        require(wbtcRise.nav() < price + (0.1*1e6), "invalid price");
    }


    /// ███ Push █████████████████████████████████████████████████████████████

    /// @notice Make sure getMaxPush returns correct values
    function testGetMaxPushReturnZeroIfLeverageRatioInRange() public {
        // Create new Rise token
        uint256 lr = 2 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        (wbtcRise, ) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        // Get max push amount
        uint256 maxAmountIn = periphery.getMaxPush(wbtcRise);

        // Checks
        require(maxAmountIn == 0, "invalid amount in");
    }

    /// @notice Make sure previewPush revert if leverage ratio in range
    function testPreviewPushRevertIfLeverageRatioInRange() public {
        // Create new Rise token
        uint256 lr = 2 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        (wbtcRise, ) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.NoNeedToRebalance.selector
            )
        );
        periphery.previewPush(wbtcRise, 1e8);
    }

    /// @notice Make sure getMaxPush returns correct values
    function testGetMaxPushAndPreviewPushReturnNonZeroIfLeverageRatioBelowRange() public {
        // Create new Rise token
        uint256 lr = 1.6 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        (wbtcRise, ) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        // Get max push amount
        uint256 maxAmountIn = periphery.getMaxPush(wbtcRise);
        uint256 amountOut = periphery.previewPush(wbtcRise, maxAmountIn);

        // Checks
        require(maxAmountIn != 0, "invalid amount in");
        require(amountOut != 0, "invalid amount out");
    }


    /// ███ Pull █████████████████████████████████████████████████████████████

    /// @notice Make sure getMaxPull returns correct values
    function testGetMaxPullReturnZeroIfLeverageRatioInRange() public {
        // Create new Rise token
        uint256 lr = 2 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        (wbtcRise, ) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        // Get max push amount
        uint256 maxAmountOut = periphery.getMaxPull(wbtcRise);

        // Checks
        require(maxAmountOut == 0, "invalid amount in");
    }

    /// @notice Make sure previewPull revert if leverage ratio in range
    function testPreviewPullRevertIfLeverageRatioInRange() public {
        // Create new Rise token
        uint256 lr = 2 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        (wbtcRise, ) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.NoNeedToRebalance.selector
            )
        );
        periphery.previewPull(wbtcRise, 1e8);
    }

    /// @notice Make sure getMaxPush returns correct values
    function testGetMaxPullAndPreviewPullReturnNonZeroIfLeverageRatioAboveRange() public {
        // Create new Rise token
        uint256 lr = 2.8 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        (wbtcRise, ) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        // Get max push amount
        uint256 maxAmountOut = periphery.getMaxPull(wbtcRise);
        uint256 amountIn = periphery.previewPull(wbtcRise, maxAmountOut);

        // Checks
        require(maxAmountOut != 0, "invalid amount out");
        require(amountIn != 0, "invalid amount in");
    }


    /// ███ Buy ██████████████████████████████████████████████████████████████

    /// @notice Make sure previewBuy revert if Rise Token is not initialized
    function testPreviewBuyRevertIfRiseTokenIsNotInitialized() public {
        // Create Rise Token
        address feeRecipient = vm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new Rise token
        RiseToken wbtcRise = factory.create(
            fwbtc,
            fusdc,
            uniswapAdapter,
            oracleAdapter
        );

        // This should be reverted
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.NotInitialized.selector
            )
        );
        periphery.previewBuy(
            wbtcRise,
            address(0),
            1 ether
        );
    }

    /// @notice Make sure previewBuy returns zero if the shares is zero
    function testPreviewBuyReturnZeroIfSharesIsZero() public {
        // Create new Rise token
        uint256 lr = 2 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        (wbtcRise, ) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        uint256 amountIn = periphery.previewBuy(
            wbtcRise,
            address(0),
            0
        );
        require(amountIn == 0, "not zero");
    }

    /// @notice Make sure previewBuy returns correct ETH amount
    function testPreviewBuyUsingETH() public {
        // Create new Rise token
        uint256 lr = 2 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        (wbtcRise, ) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        uint256 amountIn = periphery.previewBuy(
            wbtcRise,
            address(0),
            2 ether
        );

        // amountIn should greater than 2x price in ETH and less than 2.1x
        // price in ETH
        uint256 priceInETH = wbtcRise.oracleAdapter().totalValue(
            address(wbtcRise.debt()),
            address(0),
            wbtcRise.nav()
        );
        uint256 minAmountIn = priceInETH.mulWadDown(2 ether);
        uint256 maxAmountIn = priceInETH.mulWadDown(2.1 ether);
        require(amountIn > minAmountIn, "amountIn too low");
        require(amountIn < maxAmountIn, "amountIn too high");
    }

    /// @notice Make sure previewBuy returns correct collateral amount
    function testPreviewBuyUsingCollateralToken() public {
        // Create new Rise token
        uint256 lr = 2 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        (wbtcRise, ) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        uint256 amountIn = periphery.previewBuy(
            wbtcRise,
            address(wbtcRise.collateral()),
            2 ether
        );

        // amountIn should greater than 2x price in WBTC and less than 2.1x
        // price in WBTC
        uint256 priceInWBTC = wbtcRise.oracleAdapter().totalValue(
            address(wbtcRise.debt()),
            address(wbtcRise.collateral()),
            wbtcRise.nav()
        );
        uint256 minAmountIn = priceInWBTC.mulWadDown(2 ether);
        uint256 maxAmountIn = priceInWBTC.mulWadDown(2.1 ether);
        require(amountIn > minAmountIn, "amountIn too low");
        require(amountIn < maxAmountIn, "amountIn too high");
    }

    /// @notice Make sure previewBuy returns correct USDC amount
    function testPreviewBuyUsingDebtToken() public {
        // Create new Rise token
        uint256 lr = 2 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        (wbtcRise, ) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        uint256 amountIn = periphery.previewBuy(
            wbtcRise,
            address(wbtcRise.debt()),
            2 ether
        );

        // amountIn should greater than 2x price in USDC and less than 2.1x
        // price in USDC
        uint256 minAmountIn = wbtcRise.nav().mulWadDown(2 ether);
        uint256 maxAmountIn = wbtcRise.nav().mulWadDown(2.1 ether);
        require(amountIn > minAmountIn, "amountIn too low");
        require(amountIn < maxAmountIn, "amountIn too high");
    }


    /// ███ Sell █████████████████████████████████████████████████████████████

    /// @notice Make sure previewSell revert if Rise Token is not initialized
    function testPreviewSellRevertIfRiseTokenIsNotInitialized() public {
        // Create Rise Token
        address feeRecipient = vm.addr(1);
        RiseTokenFactory factory = new RiseTokenFactory(feeRecipient);

        // Create new Rise token
        RiseToken wbtcRise = factory.create(
            fwbtc,
            fusdc,
            uniswapAdapter,
            oracleAdapter
        );

        // This should be reverted
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.NotInitialized.selector
            )
        );
        periphery.previewSell(
            wbtcRise,
            address(0),
            1 ether
        );
    }

    /// @notice Make sure previewSell returns zero if the shares is zero
    function testPreviewSellReturnZeroIfSharesIsZero() public {
        // Create new Rise token
        uint256 lr = 2 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        (wbtcRise, ) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        uint256 amountOut = periphery.previewSell(
            wbtcRise,
            address(0),
            0
        );
        require(amountOut == 0, "not zero");
    }

    /// @notice Make sure previewSell returns correct ETH amount
    function testPreviewSellToETH() public {
        // Create new Rise token
        uint256 lr = 2 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        (wbtcRise, ) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        uint256 amountOut = periphery.previewSell(
            wbtcRise,
            address(0),
            2 ether
        );

        // amountOut should less than 2x price in ETH and greater than 1.9x
        // price in ETH
        uint256 priceInETH = wbtcRise.oracleAdapter().totalValue(
            address(wbtcRise.debt()),
            address(0),
            wbtcRise.nav()
        );
        uint256 minAmountOut = priceInETH.mulWadDown(1.9 ether);
        uint256 maxAmountOut = priceInETH.mulWadDown(2 ether);
        require(amountOut > minAmountOut, "amountOut too low");
        require(amountOut < maxAmountOut, "amountOut too high");
    }

    /// @notice Make sure previewSell returns correct collateral amount
    function testPreviewSellToCollateralToken() public {
        // Create new Rise token
        uint256 lr = 2 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        (wbtcRise, ) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        uint256 amountOut = periphery.previewSell(
            wbtcRise,
            address(wbtcRise.collateral()),
            2 ether
        );

        // amountOut should greater than 1.9x price in WBTC and less than 2x
        // price in WBTC
        uint256 priceInWBTC = wbtcRise.oracleAdapter().totalValue(
            address(wbtcRise.debt()),
            address(wbtcRise.collateral()),
            wbtcRise.nav()
        );
        uint256 minAmountOut = priceInWBTC.mulWadDown(1.9 ether);
        uint256 maxAmountOut = priceInWBTC.mulWadDown(2 ether);
        require(amountOut > minAmountOut, "amountOut too low");
        require(amountOut < maxAmountOut, "amountOut too high");
    }

    /// @notice Make sure previewSell returns correct USDC amount
    function testPreviewSellToDebtToken() public {
        // Create new Rise token
        uint256 lr = 2 ether;
        uint256 price = 400 * 1e6; // 400 UDSC
        uint256 collateralAmount = 1 * 1e8; // 1 WBTC
        RiseToken wbtcRise;
        (wbtcRise, ) = createRiseToken(
            collateralAmount,
            price,
            lr
        );

        uint256 amountOut = periphery.previewSell(
            wbtcRise,
            address(wbtcRise.debt()),
            2 ether
        );

        // amountOut should greater than 1.9x price in USDC and less than 2x
        // price in USDC
        uint256 minAmountOut = wbtcRise.nav().mulWadDown(1.9 ether);
        uint256 maxAmountOut = wbtcRise.nav().mulWadDown(2 ether);
        require(amountOut > minAmountOut, "amountOut too low");
        require(amountOut < maxAmountOut, "amountOut too high");
    }
}
