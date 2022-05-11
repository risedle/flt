// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

import { IVM } from "./IVM.sol";
import { VMUtils } from "./VMUtils.sol";

import { RiseTokenUtils } from "./RiseTokenUtils.sol";
import { RiseTokenPeriphery } from "../RiseTokenPeriphery.sol";

import { RiseToken } from "../RiseToken.sol";
import { IRiseToken } from "../interfaces/IRiseToken.sol";

/**
 * @title Rise Token Buy & Sell Test
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 */
contract RiseTokenBuyAndSellTest {

    /// ███ Libraries ████████████████████████████████████████████████████████

    using FixedPointMathLib for uint256;


    /// ███ Storages █████████████████████████████████████████████████████████

    IVM private immutable vm = IVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    VMUtils                    private utils;
    RiseTokenPeriphery         private periphery;
    RiseTokenUtils             private riseTokenUtils;


    /// ███ Test Setup ███████████████████████████████████████████████████████

    function setUp() public {
        // Create utils
        utils = new VMUtils(vm);

        // Create periphery
        periphery = new RiseTokenPeriphery();

        // Create Rise Token Utils
        riseTokenUtils = new RiseTokenUtils();
    }

    /// @notice Receives ETH either refund from buy or from sell
    receive() external payable {}


    /// ███ Buy ██████████████████████████████████████████████████████████████

    /// @notice Make sure it revert when Rise Token is not initialized
    function testBuyRevertIfRiseTokenIsNotInitialized() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();

        // Buy WBTCRISE with ETH
        uint256 ethAmount = 1 ether;
        uint256 shares = 1 ether;
        address recipient = address(this);
        address tokenIn = address(0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.NotInitialized.selector
            )
        );
        wbtcRise.buy{value: ethAmount}(
            shares,
            recipient,
            tokenIn,
            ethAmount
        );
    }

    /// @notice Make sure it revert when buy more than max buy
    function testBuyRevertIfMoreThanMaxBuy() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);
        riseTokenUtils.setMaxBuy(wbtcRise, 2 ether);

        // Buy WBTCRISE with ETH
        uint256 ethAmount = 10 ether;
        uint256 shares = 10 ether;
        address recipient = address(this);
        address tokenIn = address(0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.SwapAmountTooLarge.selector
            )
        );
        wbtcRise.buy{value: ethAmount}(
            shares,
            recipient,
            tokenIn,
            ethAmount
        );
    }

    /// @notice Make sure it revert when slippage is too high
    function testBuyUsingETHRevertIfSlippageIsTooHigh() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);

        // Buy WBTCRISE with ETH
        uint256 shares = 1 ether;
        uint256 amountIn = periphery.previewBuy(
            wbtcRise,
            address(0),
            shares
        );
        uint256 slippage = 0.05 ether; // 5%
        amountIn -= slippage.mulWadDown(amountIn);
        address recipient = address(this);
        address tokenIn = address(0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.SlippageTooHigh.selector
            )
        );
        wbtcRise.buy{value: amountIn}(shares, recipient, tokenIn, amountIn);
    }

    /// @notice Make sure it revert when slippage is too high
    function testBuyUsingCollateralTokenRevertIfSlippageIsTooHigh() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);

        // Buy WBTCRISE with WBTC
        uint256 shares = 1 ether;
        uint256 amountIn = periphery.previewBuy(
            wbtcRise,
            address(wbtcRise.collateral()),
            shares
        );
        uint256 slippage = 0.05 ether; // 5%
        amountIn -= slippage.mulWadDown(amountIn);
        address recipient = address(this);
        address tokenIn = address(wbtcRise.collateral());

        // Top Up and approve
        utils.setWBTCBalance(address(this), amountIn);
        wbtcRise.collateral().approve(address(wbtcRise), amountIn);

        // Buy
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.SlippageTooHigh.selector
            )
        );
        wbtcRise.buy(shares, recipient, tokenIn, amountIn);
    }

    /// @notice Make sure it revert when slippage is too high
    function testBuyUsingDebtTokenRevertIfSlippageIsTooHigh() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);

        // Buy WBTCRISE with USDC
        uint256 shares = 1 ether;
        uint256 amountIn = periphery.previewBuy(
            wbtcRise,
            address(wbtcRise.debt()),
            shares
        );
        uint256 slippage = 0.05 ether; // 5%
        amountIn -= slippage.mulWadDown(amountIn);
        address recipient = address(this);
        address tokenIn = address(wbtcRise.debt());

        // Top Up and approve
        utils.setUSDCBalance(address(this), amountIn);
        wbtcRise.debt().approve(address(wbtcRise), amountIn);

        // Buy
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.SlippageTooHigh.selector
            )
        );
        wbtcRise.buy(shares, recipient, tokenIn, amountIn);
    }

    /// @notice Make sure Rise Token have correct states after buy with ETH
    function testBuyUsingETH() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);

        // Make sure these values does not change after buy
        uint256 cps = wbtcRise.collateralPerShare();
        uint256 dps = wbtcRise.debtPerShare();
        uint256 price = wbtcRise.nav();
        uint256 lr  = wbtcRise.leverageRatio();

        // Make sure these values is increased after buy
        uint256 prevTotalSupply = wbtcRise.totalSupply();
        uint256 prevFeeBalance = wbtcRise.balanceOf(
            wbtcRise.factory().feeRecipient()
        );

        // Make sure excess ETH is refunded
        uint256 prevBalance = address(this).balance;

        // Buy WBTCRISE with ETH
        uint256 amountInMax = periphery.previewBuy(
            wbtcRise,
            address(0),
            1_000 ether // Buy 1K WBTCRISE
        );
        uint256 slippage = 0.03 ether; // 3%
        amountInMax += slippage.mulWadDown(amountInMax);

        uint256 amountIn = wbtcRise.buy{value: amountInMax}(
            1_000 ether, // Buy 1K WBTCRISE
            address(this),
            address(0),
            amountInMax
        );

        // Check the balance
        require(
            wbtcRise.balanceOf(address(this)) == 1_000 ether,
            "invalid shares"
        );

        // Check the values
        require(wbtcRise.collateralPerShare() == cps, "invalid cps");
        require(wbtcRise.debtPerShare() == dps, "invalid dps");
        require(wbtcRise.nav() == price, "invalid price");

        require(wbtcRise.leverageRatio() < lr + 0.000001 ether, "invalid lr");
        require(wbtcRise.leverageRatio() > lr - 0.000001 ether, "invalid lr");

        uint256 feeBalance = wbtcRise.balanceOf(
            wbtcRise.factory().feeRecipient()
        );
        uint256 fee = wbtcRise.fees().mulWadDown(1_000 ether);
        require(
            wbtcRise.totalSupply() == prevTotalSupply + 1_000 ether + fee,
            "invalid totalSupply"
        );
        require(
            feeBalance == prevFeeBalance + fee,
            "invalid fee"
        );

        // Check refund
        require(
            address(this).balance == prevBalance - amountIn,
            "invalid balance"
        );
    }

    /// @notice Make sure Rise Token have correct states after buy with collateral token
    function testBuyUsingCollateralToken() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);

        // Make sure these values does not change after buy
        uint256 cps = wbtcRise.collateralPerShare();
        uint256 dps = wbtcRise.debtPerShare();
        uint256 price = wbtcRise.nav();
        uint256 lr  = wbtcRise.leverageRatio();

        // Make sure these values is increased after buy
        uint256 prevTotalSupply = wbtcRise.totalSupply();
        uint256 prevFeeBalance = wbtcRise.balanceOf(
            wbtcRise.factory().feeRecipient()
        );

        // Buy WBTCRISE with ETH
        uint256 amountInMax = periphery.previewBuy(
            wbtcRise,
            address(wbtcRise.collateral()),
            1_000 ether // Buy 1K WBTCRISE
        );

        uint256 slippage = 0.025 ether; // 2.5%
        amountInMax += slippage.mulWadDown(amountInMax);
        utils.setWBTCBalance(address(this), amountInMax);
        wbtcRise.collateral().approve(address(wbtcRise), amountInMax);

        uint256 amountIn = wbtcRise.buy(
            1_000 ether, // Buy 1K WBTCRISE
            address(this),
            address(wbtcRise.collateral()),
            amountInMax
        );

        // Check the balance
        require(
            wbtcRise.balanceOf(address(this)) == 1_000 ether,
            "invalid shares"
        );

        // Check the values
        require(wbtcRise.collateralPerShare() == cps, "invalid cps");
        require(wbtcRise.debtPerShare() == dps, "invalid dps");
        require(wbtcRise.nav() == price, "invalid price");

        require(wbtcRise.leverageRatio() < lr + 0.000001 ether, "invalid lr");
        require(wbtcRise.leverageRatio() > lr - 0.000001 ether, "invalid lr");

        uint256 feeBalance = wbtcRise.balanceOf(
            wbtcRise.factory().feeRecipient()
        );
        uint256 fee = wbtcRise.fees().mulWadDown(1_000 ether);
        require(
            wbtcRise.totalSupply() == prevTotalSupply + 1_000 ether + fee,
            "invalid totalSupply"
        );
        require(
            feeBalance == prevFeeBalance + fee,
            "invalid fee"
        );

        // Check refund
        require(
            wbtcRise.collateral().balanceOf(address(this)) == amountInMax - amountIn,
            "invalid balance"
        );
    }

    /// @notice Make sure Rise Token have correct states after buy using debt token
    function testBuyUsingDebtToken() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);

        // Make sure these values does not change after buy
        uint256 cps = wbtcRise.collateralPerShare();
        uint256 dps = wbtcRise.debtPerShare();
        uint256 price = wbtcRise.nav();
        uint256 lr  = wbtcRise.leverageRatio();

        // Make sure these values is increased after buy
        uint256 prevTotalSupply = wbtcRise.totalSupply();
        uint256 prevFeeBalance = wbtcRise.balanceOf(
            wbtcRise.factory().feeRecipient()
        );

        // Buy WBTCRISE with Debt token
        uint256 amountInMax = periphery.previewBuy(
            wbtcRise,
            address(wbtcRise.debt()),
            1 ether // Buy 1 WBTCRISE
        );

        uint256 slippage = 0.04 ether; // 4%
        amountInMax += slippage.mulWadDown(amountInMax);
        utils.setUSDCBalance(address(this), amountInMax);
        wbtcRise.debt().approve(address(wbtcRise), amountInMax);

        uint256 amountIn = wbtcRise.buy(
            1 ether, // Buy 1K WBTCRISE
            address(this),
            address(wbtcRise.debt()),
            amountInMax
        );

        // Check the balance
        require(
            wbtcRise.balanceOf(address(this)) == 1 ether,
            "invalid shares"
        );

        // Check the values
        require(wbtcRise.collateralPerShare() == cps, "invalid cps");
        require(wbtcRise.debtPerShare() == dps, "invalid dps");
        require(wbtcRise.nav() == price, "invalid price");

        require(wbtcRise.leverageRatio() < lr + 0.000001 ether, "invalid lr");
        require(wbtcRise.leverageRatio() > lr - 0.000001 ether, "invalid lr");

        uint256 feeBalance = wbtcRise.balanceOf(
            wbtcRise.factory().feeRecipient()
        );
        uint256 fee = wbtcRise.fees().mulWadDown(1 ether);
        require(
            wbtcRise.totalSupply() == prevTotalSupply + 1 ether + fee,
            "invalid totalSupply"
        );
        require(
            feeBalance == prevFeeBalance + fee,
            "invalid fee"
        );

        // Check refund
        require(
            wbtcRise.debt().balanceOf(address(this)) == amountInMax - amountIn,
            "invalid balance"
        );
    }


    /// ███ Sell █████████████████████████████████████████████████████████████

    /// @notice Make sure it revert when Rise Token is not initialized
    function testSellRevertIfRiseTokenIsNotInitialized() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();

        // Buy WBTCRISE with ETH
        uint256 ethAmount = 1 ether;
        uint256 shares = 1 ether;
        address recipient = vm.addr(1);
        address tokenIn = address(0);

        wbtcRise.approve(address(wbtcRise), shares);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.NotInitialized.selector
            )
        );
        wbtcRise.sell(shares, recipient, tokenIn, ethAmount);
    }

    /// @notice Make sure it revert when slippage is too high
    function testSellToETHRevertIfSlippageIsTooHigh() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);

        // Buy WBTCRISE with ETH
        uint256 shares = 1 ether;
        uint256 maxAmountIn = periphery.previewBuy(
            wbtcRise,
            address(0),
            shares
        );
        uint256 slippage = 0.05 ether; // 5%
        maxAmountIn += slippage.mulWadDown(maxAmountIn);
        address recipient = address(this);
        address tokenIn = address(0);
        wbtcRise.buy{value: maxAmountIn}(
            shares,
            recipient,
            tokenIn,
            maxAmountIn
        );

        // Sell the shares
        uint256 minAmountOut = periphery.previewSell(
            wbtcRise,
            address(0),
            shares
        );
        minAmountOut += slippage.mulWadDown(minAmountOut);
        wbtcRise.approve(address(wbtcRise), shares);
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.SlippageTooHigh.selector
            )
        );
        wbtcRise.sell(shares, recipient, address(0), minAmountOut);
    }

    /// @notice Make sure it revert when slippage is too high
    function testSellToCollateralTokenRevertIfSlippageIsTooHigh() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);

        // Buy WBTCRISE with ETH
        uint256 shares = 1 ether;
        uint256 maxAmountIn = periphery.previewBuy(
            wbtcRise,
            address(0),
            shares
        );
        uint256 slippage = 0.05 ether; // 5%
        maxAmountIn += slippage.mulWadDown(maxAmountIn);
        address recipient = address(this);
        address tokenIn = address(0);
        wbtcRise.buy{value: maxAmountIn}(
            shares,
            recipient,
            tokenIn,
            maxAmountIn
        );

        // Sell the shares to WBTC
        uint256 minAmountOut = periphery.previewSell(
            wbtcRise,
            address(wbtcRise.collateral()),
            shares
        );
        minAmountOut += slippage.mulWadDown(minAmountOut);
        wbtcRise.approve(address(wbtcRise), shares);
        address collateral = address(wbtcRise.collateral());
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.SlippageTooHigh.selector
            )
        );
        wbtcRise.sell(
            shares,
            recipient,
            collateral,
            minAmountOut
        );
    }

    /// @notice Make sure it revert when slippage is too high
    function testSellToDebtTokenRevertIfSlippageIsTooHigh() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);

        // Buy WBTCRISE with ETH
        uint256 shares = 1 ether;
        uint256 maxAmountIn = periphery.previewBuy(
            wbtcRise,
            address(0),
            shares
        );
        uint256 slippage = 0.05 ether; // 5%
        maxAmountIn += slippage.mulWadDown(maxAmountIn);
        address recipient = address(this);
        address tokenIn = address(0);
        wbtcRise.buy{value: maxAmountIn}(
            shares,
            recipient,
            tokenIn,
            maxAmountIn
        );

        // Sell the shares to USDC
        uint256 minAmountOut = periphery.previewSell(
            wbtcRise,
            address(wbtcRise.debt()),
            shares
        );
        minAmountOut += slippage.mulWadDown(minAmountOut);
        wbtcRise.approve(address(wbtcRise), shares);
        address debt = address(wbtcRise.debt());
        vm.expectRevert(
            abi.encodeWithSelector(
                IRiseToken.SlippageTooHigh.selector
            )
        );
        wbtcRise.sell(
            shares,
            recipient,
            debt,
            minAmountOut
        );
    }

    /// @notice Make sure Rise Token have correct states after selling to ETH
    function testSellToETH() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);

        // Buy WBTCRISE with ETH
        uint256 amountInMax = periphery.previewBuy(
            wbtcRise,
            address(0),
            1_000 ether // Buy 1K WBTCRISE
        );
        uint256 slippage = 0.03 ether; // 3%
        amountInMax += slippage.mulWadDown(amountInMax);

        wbtcRise.buy{value: amountInMax}(
            1_000 ether, // Buy 1K WBTCRISE
            address(this),
            address(0),
            amountInMax
        );

        // Make sure these values does not change after sell
        uint256 cps = wbtcRise.collateralPerShare();
        uint256 dps = wbtcRise.debtPerShare();
        uint256 price = wbtcRise.nav();
        uint256 lr  = wbtcRise.leverageRatio();

        // Make sure these values is decreased after sell
        uint256 prevTotalSupply = wbtcRise.totalSupply();

        // Make sure these values are increased after sell
        uint256 prevFeeBalance = wbtcRise.balanceOf(
            wbtcRise.factory().feeRecipient()
        );
        uint256 prevBalance = address(this).balance;

        // Sell to ETH
        wbtcRise.approve(address(wbtcRise), 1_000 ether);
        uint256 minAmountOut = periphery.previewSell(
            wbtcRise,
            address(0),
            1_000 ether
        );
        minAmountOut -= slippage.mulWadDown(minAmountOut);
        uint256 amountOut = wbtcRise.sell(
            1_000 ether,
            address(this),
            address(0),
            minAmountOut
        );

        // Check the balance
        require(
            wbtcRise.balanceOf(address(this)) == 0 ether,
            "invalid shares"
        );

        // Check the values
        require(wbtcRise.collateralPerShare() == cps, "invalid cps");
        require(wbtcRise.debtPerShare() == dps, "invalid dps");
        require(wbtcRise.nav() == price, "invalid price");

        require(wbtcRise.leverageRatio() < lr + 0.000001 ether, "invalid lr");
        require(wbtcRise.leverageRatio() > lr - 0.000001 ether, "invalid lr");

        uint256 feeBalance = wbtcRise.balanceOf(
            wbtcRise.factory().feeRecipient()
        );
        uint256 fee = wbtcRise.fees().mulWadDown(1_000 ether);
        require(
            wbtcRise.totalSupply() == prevTotalSupply - 1_000 ether + fee,
            "invalid totalSupply"
        );
        require(
            feeBalance == prevFeeBalance + fee,
            "invalid fee"
        );

        // Check recipient
        require(
            address(this).balance == prevBalance + amountOut,
            "invalid balance"
        );
    }

    /// @notice Make sure Rise Token have correct states after sell to collateral token
    function testSellToCollateralToken() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);

        // Buy WBTCRISE with ETH
        uint256 amountInMax = periphery.previewBuy(
            wbtcRise,
            address(0),
            1_000 ether // Buy 1K WBTCRISE
        );
        uint256 slippage = 0.03 ether; // 3%
        amountInMax += slippage.mulWadDown(amountInMax);

        wbtcRise.buy{value: amountInMax}(
            1_000 ether, // Buy 1K WBTCRISE
            address(this),
            address(0),
            amountInMax
        );

        // Make sure these values does not change after sell
        uint256 cps = wbtcRise.collateralPerShare();
        uint256 dps = wbtcRise.debtPerShare();
        uint256 price = wbtcRise.nav();
        uint256 lr  = wbtcRise.leverageRatio();

        // Make sure these values is decreased after sell
        uint256 prevTotalSupply = wbtcRise.totalSupply();

        // Make sure these values are increased after sell
        uint256 prevFeeBalance = wbtcRise.balanceOf(
            wbtcRise.factory().feeRecipient()
        );
        uint256 prevBalance = wbtcRise.collateral().balanceOf(address(this));

        // Sell to ETH
        wbtcRise.approve(address(wbtcRise), 1_000 ether);
        uint256 minAmountOut = periphery.previewSell(
            wbtcRise,
            address(wbtcRise.collateral()),
            1_000 ether
        );
        minAmountOut -= slippage.mulWadDown(minAmountOut);
        uint256 amountOut = wbtcRise.sell(
            1_000 ether,
            address(this),
            address(wbtcRise.collateral()),
            minAmountOut
        );

        // Check the balance
        require(
            wbtcRise.balanceOf(address(this)) == 0 ether,
            "invalid shares"
        );

        // Check the values
        require(wbtcRise.collateralPerShare() == cps, "invalid cps");
        require(wbtcRise.debtPerShare() == dps, "invalid dps");
        require(wbtcRise.nav() == price, "invalid price");

        require(wbtcRise.leverageRatio() < lr + 0.000001 ether, "invalid lr");
        require(wbtcRise.leverageRatio() > lr - 0.000001 ether, "invalid lr");

        uint256 feeBalance = wbtcRise.balanceOf(
            wbtcRise.factory().feeRecipient()
        );
        uint256 fee = wbtcRise.fees().mulWadDown(1_000 ether);
        require(
            wbtcRise.totalSupply() == prevTotalSupply - 1_000 ether + fee,
            "invalid totalSupply"
        );
        require(
            feeBalance == prevFeeBalance + fee,
            "invalid fee"
        );

        // Check recipient
        require(
            wbtcRise.collateral().balanceOf(address(this)) == prevBalance + amountOut,
            "invalid balance"
        );
    }

    /// @notice Make sure Rise Token have correct states after sell to debt token
    function testSellToDebtToken() public {
        // Create Rise Token
        RiseToken wbtcRise = riseTokenUtils.createWBTCRISE();
        riseTokenUtils.initializeWBTCRISE{value: 10 ether}(wbtcRise, 2 ether);

        // Buy WBTCRISE with ETH
        uint256 amountInMax = periphery.previewBuy(
            wbtcRise,
            address(0),
            1_000 ether // Buy 1K WBTCRISE
        );
        uint256 slippage = 0.03 ether; // 3%
        amountInMax += slippage.mulWadDown(amountInMax);

        wbtcRise.buy{value: amountInMax}(
            1_000 ether, // Buy 1K WBTCRISE
            address(this),
            address(0),
            amountInMax
        );

        // Make sure these values does not change after sell
        uint256 cps = wbtcRise.collateralPerShare();
        uint256 dps = wbtcRise.debtPerShare();
        uint256 price = wbtcRise.nav();
        uint256 lr  = wbtcRise.leverageRatio();

        // Make sure these values is decreased after sell
        uint256 prevTotalSupply = wbtcRise.totalSupply();

        // Make sure these values are increased after sell
        uint256 prevFeeBalance = wbtcRise.balanceOf(
            wbtcRise.factory().feeRecipient()
        );
        uint256 prevBalance = wbtcRise.debt().balanceOf(address(this));

        // Sell to ETH
        wbtcRise.approve(address(wbtcRise), 1_000 ether);
        uint256 minAmountOut = periphery.previewSell(
            wbtcRise,
            address(wbtcRise.collateral()),
            1_000 ether
        );
        minAmountOut -= slippage.mulWadDown(minAmountOut);
        uint256 amountOut = wbtcRise.sell(
            1_000 ether,
            payable(address(this)),
            address(wbtcRise.debt()),
            minAmountOut
        );

        // Check the balance
        require(
            wbtcRise.balanceOf(address(this)) == 0 ether,
            "invalid shares"
        );

        // Check the values
        require(wbtcRise.collateralPerShare() == cps, "invalid cps");
        require(wbtcRise.debtPerShare() == dps, "invalid dps");
        require(wbtcRise.nav() == price, "invalid price");

        require(wbtcRise.leverageRatio() < lr + 0.000001 ether, "invalid lr");
        require(wbtcRise.leverageRatio() > lr - 0.000001 ether, "invalid lr");

        uint256 feeBalance = wbtcRise.balanceOf(
            wbtcRise.factory().feeRecipient()
        );
        uint256 fee = wbtcRise.fees().mulWadDown(1_000 ether);
        require(
            wbtcRise.totalSupply() == prevTotalSupply - 1_000 ether + fee,
            "invalid totalSupply"
        );
        require(
            feeBalance == prevFeeBalance + fee,
            "invalid fee"
        );

        // Check recipient
        require(
            wbtcRise.debt().balanceOf(address(this)) == prevBalance + amountOut,
            "invalid balance"
        );
    }

}
