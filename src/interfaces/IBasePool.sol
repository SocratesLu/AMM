// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBasePool {
    enum SwapKind { EXACT_IN, EXACT_OUT }
    enum LiquidityKind { ADD, REMOVE }

    struct SwapRequest {
        SwapKind kind;
        uint256[] tokenScaled18Amount;
        uint256 scaled18Amount;
        uint256 tokenInIndex;
        uint256 tokenOutIndex;
        
    }

    struct LiquidityRequest {
        LiquidityKind kind;
        uint256[] tokenScaled18Amount;
        uint256[] scaled18AmountIn;
        uint256 lpTokenAmount;
        address user;
    }

    struct PoolTokenInfo {
        address[] tokens;
        uint256[] balances;
    }

    function onSwap(SwapRequest memory request) external returns (uint256);
    function onAddLiquidity(LiquidityRequest memory request) external returns (uint256);
    function onRemoveLiquidity(LiquidityRequest memory request) external returns (uint256[] memory);
    function mintLPTokens(address user, uint256 amount) external;
    function burnLPTokens(uint256 amount) external;
}
