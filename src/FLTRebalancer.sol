// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "solmate/utils/FixedPointMathLib.sol";

/**
 * @title FLTRebalancer
 * @author bayu <bayu@risedle.com> <https://github.com/pyk>
 * @notice This is just example contract on how people can make money in FLT
 *         market by contributing as rebalancer.
 *
 *         Rebalancer is incentivized to keep leverage ratio closely to
 *         target leverage ratio while the traders enjoy trading leveraged
 *         tokens without risk of liquidation.
 */
contract FLTRebalancer {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    address public recipient;

    constructor(address _recipient) {
        recipient = _recipient;
    }

    /**
     * @notice Get available rebalances to execute
     * @dev Only call this function off-chain
     * @param _flts list of FLT
     * @param _minProfits in ether
     * @return _calls Calldata that can be executed directly
     */
    function getRebalances(address[] memory _flts, uint256[] memory _minProfits)
        external
        view
        returns (bytes[] memory _calls)
    {
        uint256 n = _flts.length;
        require(n == _minProfits.length, "INVALID");

        _calls = new bytes[](n);

        for(uint256 i = 0; i < _flts.length; i++) {
            // Get FLT
            FLT flt = FLT(_flts[i]);
            uint256 minProfitInETH = _minProfits[i];

            // Check leverage ratio and target leverage ratio
            uint256 lr = flt.leverageRatio();
            uint256 maxLr = flt.maxLeverageRatio();
            uint256 minLr = flt.minLeverageRatio();

            if (lr > maxLr) {
                _calls[i] = previewLeverageDown(flt, minProfitInETH);
            } else if (lr < minLr) {
                _calls[i] = previewLeverageUp(flt, minProfitInETH);
            }
        }
        return _calls;
    }

    function getLeverageDownInOut(FLT _flt)
        internal
        view
        returns (uint256 _amountIn, uint256 _amountOut)
    {
        address c = address(_flt.collateral());
        address d = address(_flt.debt());

        uint256 lr = _flt.leverageRatio();
        uint256 mlr = _flt.maxLeverageRatio();
        uint256 mi = _flt.maxIncentive();
        uint256 md = _flt.maxDrift();
        uint256 tlr = _flt.targetLeverageRatio();

        Oracle oracle = _flt.oracleAdapter();

        // Get max amount out
        uint256 step = (lr - tlr).mulWadDown(0.5 ether);
        uint256 maxAmountOutInETH = step.mulWadDown(
            _flt.value(
                _flt.totalSupply()
            )
        );
        uint256 maxAmountOut = oracle.totalValue(
            address(0),
            c,
            maxAmountOutInETH
        );

        uint256 incentive = (lr - mlr).mulDivDown(mi, md);
        if (incentive > mi) incentive = mi;

        uint256 maxIncentive = incentive.mulWadDown(maxAmountOut);
        uint256 estAmountOut = maxAmountOut - maxIncentive;
        _amountIn = oracle.totalValue(
            c,
            d,
            estAmountOut
        );
        _amountOut = estAmountOut + incentive.mulWadDown(estAmountOut);
    }

    function getLeverageUpInOut(FLT _flt)
        internal
        view
        returns (uint256 _amountIn, uint256 _amountOut)
    {
        address c = address(_flt.collateral());
        address d = address(_flt.debt());

        uint256 lr = _flt.leverageRatio();
        uint256 mlr = _flt.minLeverageRatio();
        uint256 mi = _flt.maxIncentive();
        uint256 md = _flt.maxDrift();

        Oracle oracle = _flt.oracleAdapter();

        // Get max amount out
        uint256 step = (_flt.targetLeverageRatio() - lr).mulWadDown(0.5 ether);
        uint256 maxAmountOutInETH = step.mulWadDown(
            _flt.value(
                _flt.totalSupply()
            )
        );
        uint256 maxAmountOut = oracle.totalValue(
            address(0),
            d,
            maxAmountOutInETH
        );

        uint256 incentive = (mlr - lr).mulDivDown(mi, md);
        if (incentive > mi) incentive = mi;

        uint256 maxIncentive = incentive.mulWadDown(maxAmountOut);
        uint256 estAmountOut = maxAmountOut - maxIncentive;
        _amountIn = oracle.totalValue(
            d,
            c,
            estAmountOut
        );
        _amountOut = estAmountOut + incentive.mulWadDown(estAmountOut);
    }

    function previewLeverageDown(FLT _flt, uint256 _minProfitInETH)
        internal
        view
        returns (bytes memory _calldata)
    {
        address debt = address(_flt.debt());
        address collateral = address(_flt.collateral());

        (
            uint256 amountIn,
            uint256 amountOut
        ) = getLeverageDownInOut(_flt);

        address[] memory path = new address[](2);
        path[0] = address(collateral);
        path[1] = address(debt);

        uint256 output = _flt.router().getAmountsIn(amountIn, path)[0];
        uint256 profit = 0;
        if (amountOut > output) {
            profit = amountOut - output;
        }
        if (profit == 0) return _calldata;

        uint256 profitInETH = _flt.oracleAdapter().totalValue(
            collateral,
            _flt.router().WETH(),
            profit
        );
        if (profitInETH < _minProfitInETH) return _calldata;

        return abi.encodeWithSelector(
            FLTRebalancer.leverageDown.selector,
            _flt,
            _minProfitInETH
        );
    }

    function previewLeverageUp(FLT _flt, uint256 _minProfitInETH)
        internal
        view
        returns (bytes memory _calldata)
    {
        address debt = address(_flt.debt());
        address collateral = address(_flt.collateral());

        (
            uint256 amountIn,
            uint256 amountOut
        ) = getLeverageUpInOut(_flt);

        address[] memory path = new address[](2);
        path[0] = address(debt);
        path[1] = address(collateral);

        uint256 output = _flt.router().getAmountsIn(amountIn, path)[0];
        uint256 profit = 0;
        if (amountOut > output) {
            profit = amountOut - output;
        }
        if (profit == 0) return _calldata;

        uint256 profitInETH = _flt.oracleAdapter().totalValue(
            debt,
            _flt.router().WETH(),
            profit
        );
        if (profitInETH < _minProfitInETH) return _calldata;

        return abi.encodeWithSelector(
            FLTRebalancer.leverageUp.selector,
            _flt,
            _minProfitInETH
        );
    }

    enum FlashSwapType {LeverageUp, LeverageDown}

    struct FlashSwapParams {
        FlashSwapType flashSwapType;

        FLT flt;
        uint256 borrowAmount;
        uint256 repayAmount;
        uint256 profitAmount;
    }

    function pancakeCall(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes memory _data
    ) external {
        _callback(_sender, _amount0, _amount1, _data);
    }

    function uniswapV2Call(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes memory _data
    ) external {
        _callback(_sender, _amount0, _amount1, _data);
    }

    function _callback(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes memory _data
    ) internal {
        // no need to check the caller coz we don't store any balance here
        FlashSwapParams memory params = abi.decode(_data, (FlashSwapParams));
        FLT flt = params.flt;

        // Make sure borrowed amount from flash swap is correct
        uint256 r = _amount0 == 0 ? _amount1 : _amount0;
        require(r == params.borrowAmount, "INVALID_BORROW");

        // we need the FLT here; leverage up or down
        if (params.flashSwapType == FlashSwapType.LeverageDown) {
            // Send debt token to flt
            flt.debt().safeTransfer(address(flt), params.borrowAmount);
            // Exec pushd
            flt.pushd();
            uint256 balance = flt.collateral().balanceOf(address(this));
            // Repay amount
            flt.collateral().safeTransfer(address(flt.pair()), params.repayAmount);
            // Send profits
            flt.collateral().safeTransfer(recipient, balance - params.repayAmount);
        } else if (params.flashSwapType == FlashSwapType.LeverageUp) {
            // Send collateral token to flt
            flt.collateral().safeTransfer(address(flt), params.borrowAmount);
            // Exec pushc
            flt.pushc();
            uint256 balance = flt.debt().balanceOf(address(this));
            // Repay amount
            flt.debt().safeTransfer(address(flt.pair()), params.repayAmount);
            // Send profits
            flt.debt().safeTransfer(recipient, balance - params.repayAmount);
        } else revert("INVALID FLASHSWAP");
    }

    function leverageDown(FLT _flt, uint256 _minProfitInETH) external {
        FlashSwapParams memory params;

        (
            uint256 amountIn,
            uint256 amountOut
        ) = getLeverageDownInOut(_flt);

        address[] memory path = new address[](2);
        path[0] = address(_flt.collateral());
        path[1] = address(_flt.debt());

        uint256 repayAmount = _flt.router().getAmountsIn(amountIn, path)[0];
        uint256 profit = 0;
        if (amountOut > repayAmount) {
            profit = amountOut - repayAmount;
        }
        require(profit > 0, "UNPROFITABLE");

        uint256 profitInETH = _flt.oracleAdapter().totalValue(
            address(_flt.collateral()),
            _flt.router().WETH(),
            profit
        );
        require(profitInETH > _minProfitInETH, "UNPROFITABLE");

        params = FlashSwapParams({
            flashSwapType: FlashSwapType.LeverageDown,
            flt: _flt,
            borrowAmount: amountIn,
            repayAmount: repayAmount,
            profitAmount: profit
        });

        // Borrow debt from pancake then push debt
        address d = address(_flt.debt());
        uint256 amount0Out = d == _flt.pair().token0() ? amountIn : 0;
        uint256 amount1Out = d == _flt.pair().token1() ? amountIn : 0;
        bytes memory data = abi.encode(params);
        _flt.pair().swap(amount0Out, amount1Out, address(this), data);
    }

    function leverageUp(FLT _flt, uint256 _minProfitInETH) external {
        FlashSwapParams memory params;

        (
            uint256 amountIn,
            uint256 amountOut
        ) = getLeverageUpInOut(_flt);

        address[] memory path = new address[](2);
        path[0] = address(_flt.debt());
        path[1] = address(_flt.collateral());

        uint256 repayAmount = _flt.router().getAmountsIn(amountIn, path)[0];
        uint256 profit = 0;
        if (amountOut > repayAmount) {
            profit = amountOut - repayAmount;
        }
        require(profit > 0, "UNPROFITABLE");

        uint256 profitInETH = _flt.oracleAdapter().totalValue(
            address(_flt.debt()),
            _flt.router().WETH(),
            profit
        );
        require(profitInETH > _minProfitInETH, "UNPROFITABLE");

        params = FlashSwapParams({
            flashSwapType: FlashSwapType.LeverageUp,
            flt: _flt,
            borrowAmount: amountIn,
            repayAmount: repayAmount,
            profitAmount: profit
        });

        // Borrow collateral from pancake then push collateral
        address c = address(_flt.collateral());
        uint256 amount0Out = c == _flt.pair().token0() ? amountIn : 0;
        uint256 amount1Out = c == _flt.pair().token1() ? amountIn : 0;
        bytes memory data = abi.encode(params);
        _flt.pair().swap(amount0Out, amount1Out, address(this), data);
    }

    function multicall(bytes[] calldata data)
        public
        payable
        returns (bytes[] memory results)
    {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
    }
}

interface Oracle {
    function totalValue(address _base, address _quote, uint256 _amount)
        external
        view
        returns (uint256);
}

interface Router {
    function WETH()
        external
        view
        returns (address);

    function getAmountsIn(uint256 _amountOut, address[] memory _path)
        external
        view
        returns (uint256[] memory _amounts);

    function getAmountsOut(uint256 _amountIn, address[] memory _path)
        external
        view
        returns (uint256[] memory _amounts);
}

interface Pair {
    function token1()
        external
        view
        returns (address);
    function token0()
        external
        view
        returns (address);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
}

interface FLT {
    function leverageRatio()
        external
        view
        returns (uint256);

    function targetLeverageRatio()
        external
        view
        returns (uint256);

    function maxLeverageRatio()
        external
        view
        returns (uint256);

    function minLeverageRatio()
        external
        view
        returns (uint256);

    function maxDrift()
        external
        view
        returns (uint256);

    function maxIncentive()
        external
        view
        returns (uint256);

    function totalSupply()
        external
        view
        returns (uint256);

    function value(uint256 _shares)
        external
        view
        returns (uint256);

    function oracleAdapter()
        external
        view
        returns (Oracle);

    function debt()
        external
        view
        returns (ERC20);

    function collateral()
        external
        view
        returns (ERC20);

    function fees()
        external
        view
        returns (uint256);

    function router()
        external
        view
        returns (Router);

    function pair()
        external
        view
        returns (Pair);

    function pushd() external;
    function pushc() external;
}
