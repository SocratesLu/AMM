pragma solidity ^0.8.0;

interface IVaultStructs {
    struct SingleSwap {
        address pool;
        uint256 tokenIndexIn;
        uint256 tokenIndexOut;
    }

    struct SwapParams {
        SingleSwap[] swaps;
        uint256 tokenAmountIn;
        uint256 minAmountOut;
        uint256 deadline;
        address user;
    }
}
