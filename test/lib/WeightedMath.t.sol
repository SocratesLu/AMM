// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/lib/WeightedMath.sol";
import "../../src/lib/FixedPoint.sol";

contract WeightedMathHelper is Test {
    using FixedPoint for uint256;

    function locCalcOutGivenIn(
        uint256 balanceIn,
        uint256 weightIn,
        uint256 balanceOut,
        uint256 weightOut,
        uint256 amountIn,
        uint256 swapFee
    ) external pure returns (uint256) {

        uint256 adjustedIn = amountIn * (FixedPoint.ONE - swapFee) / FixedPoint.ONE;
        console.log("adjustedIn", adjustedIn);
        uint256 denominator = balanceIn + adjustedIn;
        console.log("denominator", denominator);    
        uint256 base = balanceIn.divUp(denominator);
        console.log("base", base);
        uint256 exponent = weightIn.divDown(weightOut);
        console.log("exponent", exponent);
        uint256 power = base.powUp(exponent);
        console.log("power", power);

        // Because of rounding up, power can be greater than one. Using complement prevents reverts.
        return balanceOut.mulDown(power.complement());
    }

    function calcOutGivenIn(
        uint256 balanceIn,
        uint256 weightIn,
        uint256 balanceOut,
        uint256 weightOut,
        uint256 amountIn,
        uint256 swapFee
    ) external pure returns (uint256) {
        return WeightedMath._calcOutGivenIn(balanceIn, weightIn, balanceOut, weightOut, amountIn, swapFee);
    }

    function calcInGivenOut(
        uint256 balanceIn,
        uint256 weightIn,
        uint256 balanceOut,
        uint256 weightOut,
        uint256 amountOut,
        uint256 swapFee
    ) external pure returns (uint256) {
        return WeightedMath._calcInGivenOut(balanceIn, weightIn, balanceOut, weightOut, amountOut, swapFee);
    }

    function calculateInvariantUp(uint256[] memory scaled18Amounts, uint256[] memory weights) external pure returns (uint256) {
        return WeightedMath._calculateInvariantUp(scaled18Amounts, weights);
    }

    function calculateInvariantDown(uint256[] memory scaled18Amounts, uint256[] memory weights) external pure returns (uint256) {
        return WeightedMath._calculateInvariantDown(scaled18Amounts, weights);
    }
}

contract WeightedMathTest is Test {
    using FixedPoint for uint256;

    WeightedMathHelper public helper;
    uint256 constant PRECISION = 1e18;

    function setUp() public {
        helper = new WeightedMathHelper();
    }

    function test_CalcOutGivenIn() public {
        uint256 balanceIn = 100 * PRECISION;
        uint256 weightIn = 30 * PRECISION;
        uint256 balanceOut = 100 * PRECISION;
        uint256 weightOut = 70 * PRECISION;
        uint256 amountIn = 10 * PRECISION;
        uint256 swapFee = 3 * PRECISION / 1000; // 0.3%

        uint256 amountOut = helper.calcOutGivenIn(balanceIn, weightIn, balanceOut, weightOut, amountIn, swapFee);
        
        // 手动计算过程:
        // 1. 调整输入金额: 10 * (1 - 0.003) = 9.97
        // 2. 计算比率: (100 / (100 + 9.97)) ^ (30/70) ≈ 0.96008
        // 3. 计算输出: 100 * (1 - 0.96008) ≈ 3.992
        //console.log("amountOut", amountOut);
        assertApproxEqRel(amountOut, 3991198924991392000,  PRECISION / 10000000); // 允许1e-7的误差
    }

    function test_CalcInGivenOut() public {
        uint256 balanceIn = 100 * PRECISION;
        uint256 weightIn = 30 * PRECISION;
        uint256 balanceOut = 100 * PRECISION;
        uint256 weightOut = 70 * PRECISION;
        uint256 amountOut = 5 * PRECISION;
        uint256 swapFee = 3 * PRECISION / 1000; // 0.3%

        uint256 amountIn = helper.calcInGivenOut(balanceIn, weightIn, balanceOut, weightOut, amountOut, swapFee);

        // 手动计算过程:
        // 1. 计算比率: (100 / (100 - 5)) ^ (70/30) ≈ 1.12714
        // 2. 计算输入: 100 * (1.12714 - 1) ≈ 12.714
        // 3. 调整手续费: 12.714 / (1 - 0.003) ≈ 12.75

        //console.log("amountIn", amountIn);
        assertApproxEqRel(amountIn, 12752358815072496288, PRECISION / 10000000); // 允许1e-7的误差
    }

    function test_CalculateInvariant() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 * PRECISION;
        amounts[1] = 200 * PRECISION;
        amounts[2] = 300 * PRECISION;

        uint256[] memory weights = new uint256[](3);
        weights[0] = 20 * PRECISION / 100;
        weights[1] = 30 * PRECISION / 100;
        weights[2] = 50 * PRECISION / 100;

        uint256 invariantUp = helper.calculateInvariantUp(amounts, weights);
        uint256 invariantDown = helper.calculateInvariantDown(amounts, weights);

        // 手动计算过程:
        // invariant ≈ 100^0.2 * 200^0.3 * 300^0.5 ≈ 213.24

        assertApproxEqRel(invariantUp, 213240467536803789133, PRECISION / 10000000); // 允许1e-7的误差
        assertApproxEqRel(invariantDown, 213240467536790994340, PRECISION / 10000000); // 允许1e-7的误差
        
        // 确保Up版本的结果大于或等于Down版本
        assertGe(invariantUp, invariantDown);

        console.log("invariantUp", invariantUp);
        console.log("invariantDown", invariantDown);
    }

    function test_MaxInRatio() public {
        uint256 balanceIn = 100 * PRECISION;
        uint256 weightIn = 30 * PRECISION;
        uint256 balanceOut = 100 * PRECISION;
        uint256 weightOut = 70 * PRECISION;
        uint256 amountIn = 31 * PRECISION; // 超过30%的最大输入比例
        uint256 swapFee = 3 * PRECISION / 1000;

        vm.expectRevert(WeightedMath.MaxInRatio.selector);
        helper.calcOutGivenIn(balanceIn, weightIn, balanceOut, weightOut, amountIn, swapFee);
    }

    function test_MaxOutRatio() public {
        uint256 balanceIn = 100 * PRECISION;
        uint256 weightIn = 30 * PRECISION;
        uint256 balanceOut = 100 * PRECISION;
        uint256 weightOut = 70 * PRECISION;
        uint256 amountOut = 31 * PRECISION; // 超过30%的最大输出比例
        uint256 swapFee = 3 * PRECISION / 1000;

        vm.expectRevert(WeightedMath.MaxOutRatio.selector);
        helper.calcInGivenOut(balanceIn, weightIn, balanceOut, weightOut, amountOut, swapFee);
    }


    function test_ZeroInvariantDown() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 0;
        amounts[1] = 0;
        amounts[2] = 0;

        uint256[] memory weights = new uint256[](3);
        weights[0] = 20 * PRECISION;
        weights[1] = 30 * PRECISION;
        weights[2] = 50 * PRECISION;

        vm.expectRevert(WeightedMath.ZeroInvariant.selector);
        helper.calculateInvariantDown(amounts, weights);
    }

    function test_ArrayLengthMismatch() public {
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100 * PRECISION;
        amounts[1] = 200 * PRECISION;
        amounts[2] = 300 * PRECISION;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 20 * PRECISION;
        weights[1] = 30 * PRECISION;

        vm.expectRevert(WeightedMath.ArrayLengthMismatch.selector);
        helper.calculateInvariantDown(amounts, weights);
        vm.expectRevert(WeightedMath.ArrayLengthMismatch.selector);
        helper.calculateInvariantUp(amounts, weights);
    }

    // ========================TestFuzz================================

    function testFuzz_CalcOutGivenIn(uint256 amountIn) public {
        vm.assume(amountIn > 1e7 && amountIn <= 1e30); // 假设输入金额在合理范围内

        uint256 balanceIn = max(amountIn * 5, 100 * PRECISION);
        uint256 balanceOut = balanceIn * 3;
        uint256 weightIn = 30 * PRECISION;
        uint256 weightOut = 70 * PRECISION;
        uint256 swapFee = 3 * PRECISION / 1000; // 0.3%

        uint256 amountOut = helper.calcOutGivenIn(balanceIn, weightIn, balanceOut, weightOut, amountIn, swapFee);

        // 验证输出金额不为零且小于余额
        assertTrue(amountOut > 0);
        assertTrue(amountOut <= balanceOut);

    }

    function testFuzz_CalcInGivenOut(uint256 amountOut) public {
        vm.assume(amountOut > 1e7 && amountOut <= 1e30); // 假设输出金额在合理范围内

        uint256 balanceOut = max(amountOut * 5, 100 * PRECISION);
        uint256 balanceIn = balanceOut / 5;
        uint256 weightIn = 30 * PRECISION;
        uint256 weightOut = 70 * PRECISION;
        uint256 swapFee = 3 * PRECISION / 1000; // 0.3%

        uint256 amountIn = helper.calcInGivenOut(balanceIn, weightIn, balanceOut, weightOut, amountOut, swapFee);

        // 验证输入金额不为零且小于余额
        assertTrue(amountIn > 0);
        assertTrue(amountIn <= balanceIn);
    }

    // 辅助函数：返回两个数中的较大值
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function testFuzz_CalculateInvariant(uint256[3] memory fuzzAmounts, uint64[3] memory fuzzWeights) public {
        vm.assume(fuzzAmounts[0] > 1e6 && fuzzAmounts[0] <= 1e23);

        vm.assume(fuzzWeights[0] > 1e16 && fuzzWeights[0] < 4e17);
        vm.assume(fuzzWeights[1] > 1e16 && fuzzWeights[1] < 4e17);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = fuzzAmounts[0];
        amounts[1] = fuzzAmounts[0] * 2;
        amounts[2] = fuzzAmounts[0] * 3;

        uint256[] memory weights = new uint256[](3);
        weights[0] = uint256(fuzzWeights[0]) ;
        weights[1] = uint256(fuzzWeights[1]) ;
        weights[2] = PRECISION - uint256(fuzzWeights[0]) - uint256(fuzzWeights[1]);

        uint256 invariantUp = helper.calculateInvariantUp(amounts, weights);
        uint256 invariantDown = helper.calculateInvariantDown(amounts, weights);

        // 确保计算结果不为零
        assertTrue(invariantUp > 0);
        assertTrue(invariantDown > 0);

        // 确保Up版本的结果大于或等于Down版本
        assertGe(invariantUp, invariantDown);
    }
}