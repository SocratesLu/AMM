// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NormalizeAmount.sol";
import {FixedPoint} from "./FixedPoint.sol";

library WeightedMath {
    using NormalizeAmount for uint256;
    using FixedPoint for uint256;

    // Swap limits: amounts swapped may not be larger than this percentage of the total balance.
    uint256 internal constant _MAX_IN_RATIO = 30e16; // 30%
    uint256 internal constant _MAX_OUT_RATIO = 30e16; // 30%

    // errors
    error ZeroInvariant();
    error MaxInRatio();
    error MaxOutRatio();
    error ArrayLengthMismatch();

    function _calcOutGivenIn(
        uint256 balanceIn,
        uint256 weightIn,
        uint256 balanceOut,
        uint256 weightOut,
        uint256 amountIn,
        uint256 swapFee
    ) internal pure returns (uint256 amountOut) {
        /**********************************************************************************************
        // outGivenExactIn                                                                           //
        // aO = amountOut                                                                            //
        // bO = balanceOut                                                                           //
        // bI = balanceIn              /      /            bI             \    (wI / wO) \           //
        // aI = amountIn    aO = bO * |  1 - | --------------------------  | ^            |          //
        // wI = weightIn               \      \       ( bI + aI )         /              /           //
        // wO = weightOut                                                                            //
        **********************************************************************************************/
        // Cannot exceed maximum in ratio.
        if (amountIn > balanceIn.mulDown(_MAX_IN_RATIO)) {
            revert MaxInRatio();
        }

        uint256 adjustedIn = amountIn * (FixedPoint.ONE - swapFee) / FixedPoint.ONE;
        uint256 denominator = balanceIn + adjustedIn;
        uint256 base = balanceIn.divUp(denominator);
        uint256 exponent = weightIn.divDown(weightOut);
        uint256 power = base.powUp(exponent);

        // Because of rounding up, power can be greater than one. Using complement prevents reverts.
        return balanceOut.mulDown(power.complement());
    }

    function _calcInGivenOut(
        uint256 balanceIn,
        uint256 weightIn,
        uint256 balanceOut,
        uint256 weightOut,
        uint256 amountOut,
        uint256 swapFee
    ) internal pure returns (uint256 amountIn) {
        /**********************************************************************************************
        // inGivenExactOut                                                                           //
        // aO = amountOut                                                                            //
        // bO = balanceOut                                                                           //
        // bI = balanceIn              /  /            bO             \    (wO / wI)      \          //
        // aI = amountIn    aI = bI * |  | --------------------------  | ^            - 1  |         //
        // wI = weightIn               \  \       ( bO - aO )         /                   /          //
        // wO = weightOut                                                                            //
        **********************************************************************************************/

        // Cannot exceed maximum out ratio.
        if (amountOut > balanceOut.mulDown(_MAX_OUT_RATIO)) {
            revert MaxOutRatio();
        }
        
        uint256 base = balanceOut.divUp(balanceOut - amountOut);
        uint256 exponent = weightOut.divUp(weightIn);
        uint256 power = base.powUp(exponent);

        // Because the base is larger than one (and the power rounds up), the power should always be larger than one, so
        // the following subtraction should never revert.
        uint256 ratio = power - FixedPoint.ONE;
        amountIn = (balanceIn.mulUp(ratio))  * FixedPoint.ONE /(FixedPoint.ONE - swapFee);
    }

    function _calculateInvariantUp(uint256[] memory scaled18Amounts, uint256[] memory weights) internal pure returns (uint256 invariant) {
        /**********************************************************************************************
        // invariant               _____                                                             //
        // wi = weight index i      | |      wi                                                      //
        // bi = balance index i     | |  bi ^   = i                                                  //
        // i = invariant                                                                             //
        **********************************************************************************************/
        if (scaled18Amounts.length != weights.length) revert ArrayLengthMismatch();
        
        invariant = FixedPoint.ONE;
        for (uint256 i = 0; i < scaled18Amounts.length; ++i) {
            invariant = invariant.mulUp(scaled18Amounts[i].powUp(weights[i]));
        }
        if (invariant == 0) revert ZeroInvariant();
    }

     function _calculateInvariantDown(uint256[] memory scaled18Amounts, uint256[] memory weights) internal pure returns (uint256 invariant) {
        /**********************************************************************************************
        // invariant               _____                                                             //
        // wi = weight index i      | |      wi                                                      //
        // bi = balance index i     | |  bi ^   = i                                                  //
        // i = invariant                                                                             //
        **********************************************************************************************/
        if (scaled18Amounts.length != weights.length) revert ArrayLengthMismatch();
        
        invariant = FixedPoint.ONE;
        for (uint256 i = 0; i < scaled18Amounts.length; ++i) {
            invariant = invariant.mulDown(scaled18Amounts[i].powDown(weights[i]));
        }
        if (invariant == 0) revert ZeroInvariant();
    }
}