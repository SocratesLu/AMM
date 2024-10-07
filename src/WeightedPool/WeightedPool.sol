// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IBasePool.sol";
import "../interfaces/IVault.sol";
import {WeightedMath} from "../lib/WeightedMath.sol";

contract WeightedPool is ERC20, IBasePool {
    using Strings for uint256;

    error TokenWeightMismatch();
    error SwapFeeTooHigh();
    error TooManyTokens();
    error TotalWeightMismatch();
    error OnlyVaultAllowed();
    error SameTokenSwap();
    error InvalidTokenIndex();
    error AmountsLengthMismatch();
    error InsufficientLPTokens();

    uint256[] public weights;
    uint256 public constant ONE = 1e18;
    uint256 public swapFee;

    string public constant VERSION = "WeightedPool 1.0.0";

    IVault public vault;

    constructor(
        address _vault,
        uint256[] memory _weights,
        uint256 _swapFee
    ) ERC20(
        string(abi.encodePacked("WP", Strings.toHexString(uint160(address(this)), 20))),
        string(abi.encodePacked("WP", Strings.toHexString(uint160(address(this)), 20)))
    ) {
        if (_swapFee > ONE / 10) revert SwapFeeTooHigh();
        if (_weights.length >= 8) revert TooManyTokens();

        vault = IVault(_vault);
        swapFee = _swapFee;
        uint256 totalWeight = 0;

        for (uint256 i = 0; i < _weights.length; i++) {
            weights.push(_weights[i]);
            totalWeight = totalWeight + _weights[i];
        }

        if (totalWeight != ONE) revert TotalWeightMismatch();
    }

    modifier onlyVault() {
        if (msg.sender != address(vault)) revert OnlyVaultAllowed();
        _;
    }

    function onSwap(SwapRequest memory request) external override view returns (uint256) {
        if (request.kind == SwapKind.EXACT_IN) {
            return swapExactIn(
                request.tokenInIndex,
                request.tokenOutIndex,
                request.scaled18Amount,
                request.tokenScaled18Amount[request.tokenInIndex],
                request.tokenScaled18Amount[request.tokenOutIndex]
            );
        } else {
            return swapExactOut(
                request.tokenInIndex,
                request.tokenOutIndex,
                request.scaled18Amount,
                request.tokenScaled18Amount[request.tokenInIndex],
                request.tokenScaled18Amount[request.tokenOutIndex]
            );
        }
    }

    function swapExactIn(
        uint256 tokenInIndex,
        uint256 tokenOutIndex,
        uint256 normalizedAmountIn,
        uint256 normalizedBalanceIn,
        uint256 normalizedBalanceOut
    ) public view returns (uint256 normalizedAmountOut) {
        if (tokenInIndex == tokenOutIndex) revert SameTokenSwap();
        if (tokenInIndex >= weights.length || tokenOutIndex >= weights.length) revert InvalidTokenIndex();

        normalizedAmountOut = WeightedMath._calcOutGivenIn(
            normalizedBalanceIn,
            weights[tokenInIndex],
            normalizedBalanceOut,
            weights[tokenOutIndex],
            normalizedAmountIn,
            swapFee
        );

        return normalizedAmountOut;
    }

    function swapExactOut(
        uint256 tokenInIndex,
        uint256 tokenOutIndex,
        uint256 normalizedAmountOut,
        uint256 normalizedBalanceIn,
        uint256 normalizedBalanceOut
    ) public view returns (uint256 normalizedAmountIn) {
        if (tokenInIndex == tokenOutIndex) revert SameTokenSwap();
        if (tokenInIndex >= weights.length || tokenOutIndex >= weights.length) revert InvalidTokenIndex();

        normalizedAmountIn = WeightedMath._calcInGivenOut(
            normalizedBalanceIn,
            weights[tokenInIndex],
            normalizedBalanceOut,
            weights[tokenOutIndex],
            normalizedAmountOut,
            swapFee
        );

        return normalizedAmountIn;
    }

    function onAddLiquidity(LiquidityRequest memory request) external override view returns (uint256 lpTokens) {
        if (request.scaled18AmountIn.length != weights.length) revert AmountsLengthMismatch();

        uint256 invariantBefore = WeightedMath._calculateInvariantUp(request.tokenScaled18Amount, weights);
        uint256 totalSupplyBefore = totalSupply();

        uint256 minNormalizedAmount = type(uint256).max;

        for (uint256 i = 0; i < weights.length; i++) {
            if (request.scaled18AmountIn[i] > 0) {
                if (request.scaled18AmountIn[i] < minNormalizedAmount) {
                    minNormalizedAmount = request.scaled18AmountIn[i];
                }
            }
        }

        uint256[] memory newBalances = new uint256[](weights.length);
        for (uint256 i = 0; i < weights.length; i++) {
            newBalances[i] = request.tokenScaled18Amount[i] + request.scaled18AmountIn[i];
        }

        uint256 invariantAfter = WeightedMath._calculateInvariantDown(newBalances, weights);

        if (totalSupplyBefore == 0) {
            lpTokens = minNormalizedAmount; // initial liquidity
        } else {
            lpTokens = (totalSupplyBefore * (invariantAfter) / (invariantBefore))- (totalSupplyBefore);
        }

        return lpTokens;
    }

    function onRemoveLiquidity(LiquidityRequest memory request) external override view returns (uint256[] memory amounts) {
        if (request.lpTokenAmount > balanceOf(request.user)) revert InsufficientLPTokens();

        uint256 totalSupplyBefore = totalSupply();
        uint256 ratio = request.lpTokenAmount * ONE / totalSupplyBefore;

        amounts = new uint256[](weights.length);
        for (uint256 i = 0; i < weights.length; i++) {
            amounts[i] = request.tokenScaled18Amount[i] * ratio / ONE;
        }

        return amounts;
    }

    function mintLPTokens(address user, uint256 amount) external onlyVault {
        _mint(user, amount);
    }

    function burnLPTokens(uint256 amount) external onlyVault {
        _burn(msg.sender, amount);
    }

    function getWeights() public view returns (uint256[] memory) {
        return weights;
    }

    function getTokensData() public view returns (address[] memory tokens, uint256[] memory balances) {
        return vault.getPoolTokensData(address(this));
    }
}