// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./VaultStorage.sol";
import "./interfaces/IBasePool.sol";
import "./interfaces/IWETH.sol";
import "./lib/NormalizeAmount.sol";


contract VaultSwap is VaultStorage {
    using SafeERC20 for IERC20;
    using NormalizeAmount for uint256;

    function swapExactIn(SwapParams memory params) external payable nonReentrant returns (uint256 tokenAmountOut) {
        if (block.timestamp > params.deadline) revert DeadlineExpired();
        if (params.swaps.length == 0) revert EmptySwapPath();
        if (params.swaps.length > 3) revert TooManySwaps();

        SingleSwap memory firstSwap = params.swaps[0];
        SingleSwap memory lastSwap = params.swaps[params.swaps.length - 1];

        PoolTokenInfo memory firstTokenInfos = getPoolTokens(firstSwap.pool);
        address tokenInAddress = firstTokenInfos.tokens[firstSwap.tokenIndexIn];

        // Handle ETH to WETH conversion if necessary
        if (tokenInAddress == ETH_ADDRESS) {
            require(msg.value == params.tokenAmountIn, "ETH amount mismatch");
            WETH.deposit{value: params.tokenAmountIn}();
            tokenInAddress = address(WETH);
        } else {
            IERC20(tokenInAddress).safeTransferFrom(params.user, address(this), params.tokenAmountIn);
        }

        uint256 currentAmountIn = params.tokenAmountIn;

        for (uint256 i = 0; i < params.swaps.length; i++) {
            SingleSwap memory currentSwap = params.swaps[i];

            tokenAmountOut = _singleSwapExactIn(
                currentSwap.pool,
                currentSwap.tokenIndexIn,
                currentSwap.tokenIndexOut,
                currentAmountIn
            );

            if (i < params.swaps.length - 1) {
                currentAmountIn = tokenAmountOut;
            }
        }

        if (tokenAmountOut < params.minAmountOut) revert InsufficientOutputAmount();

        // Handle WETH to ETH conversion if necessary
        PoolTokenInfo memory lastTokenInfos = getPoolTokens(lastSwap.pool);
        address tokenOutAddress = lastTokenInfos.tokens[lastSwap.tokenIndexOut];
        if (tokenOutAddress == ETH_ADDRESS) {
            WETH.withdraw(tokenAmountOut);
            (bool success, ) = params.user.call{value: tokenAmountOut}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(tokenOutAddress).safeTransfer(params.user, tokenAmountOut);
        }

        return tokenAmountOut;
    }

    function swapExactOut(SwapParams memory params) external payable nonReentrant returns (uint256 tokenAmountIn) {
        if (block.timestamp > params.deadline) revert DeadlineExpired();
        if (params.swaps.length == 0) revert EmptySwapPath();
        if (params.swaps.length > 3) revert TooManySwaps();

        SingleSwap memory firstSwap = params.swaps[0];
        SingleSwap memory lastSwap = params.swaps[params.swaps.length - 1];

        PoolTokenInfo memory lastTokenInfos = getPoolTokens(lastSwap.pool);
        address tokenOutAddress = lastTokenInfos.tokens[lastSwap.tokenIndexOut];

        uint256 currentAmountOut = params.minAmountOut;

        for (uint256 i = params.swaps.length; i > 0; i--) {
            SingleSwap memory currentSwap = params.swaps[i - 1];

            tokenAmountIn = _singleSwapExactOut(
                currentSwap.pool,
                currentSwap.tokenIndexIn,
                currentSwap.tokenIndexOut,
                currentAmountOut
            );

            if (i > 1) {
                currentAmountOut = tokenAmountIn;
            }
        }

        if (tokenAmountIn > params.tokenAmountIn) revert InsufficientInputAmount();

        PoolTokenInfo memory firstTokenInfos = getPoolTokens(firstSwap.pool);
        address tokenInAddress = firstTokenInfos.tokens[firstSwap.tokenIndexIn];

        // Handle ETH to WETH conversion if necessary
        if (tokenInAddress == ETH_ADDRESS) {
            require(msg.value >= tokenAmountIn, "Insufficient ETH sent");
            WETH.deposit{value: tokenAmountIn}();
            // Refund excess ETH
            if (msg.value > tokenAmountIn) {
                (bool success, ) = params.user.call{value: msg.value - tokenAmountIn}("");
                require(success, "ETH refund failed");
            }
        } else {
            IERC20(tokenInAddress).safeTransferFrom(params.user, address(this), tokenAmountIn);
        }

        // Handle WETH to ETH conversion if necessary
        if (tokenOutAddress == ETH_ADDRESS) {
            WETH.withdraw(params.minAmountOut);
            (bool success, ) = params.user.call{value: params.minAmountOut}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(tokenOutAddress).safeTransfer(params.user, params.minAmountOut);
        }

        return tokenAmountIn;
    }

    function _singleSwapExactIn(
        address _pool,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 tokenAmountIn
    ) internal poolLived(_pool) returns (uint256 tokenAmountOut) {
        PoolTokenInfo memory tokenInfos = getPoolTokens(_pool);
        IERC20 tokenIn = IERC20(tokenInfos.tokens[tokenIndexIn]);
        IERC20 tokenOut = IERC20(tokenInfos.tokens[tokenIndexOut]);

        tokenIn.safeTransferFrom(msg.sender, address(this), tokenAmountIn);
        
        uint256[] memory tokenScaled18Amount = new uint256[](tokenInfos.tokens.length);
        for (uint256 i = 0; i < tokenInfos.tokens.length; i++) {
            tokenScaled18Amount[i] = tokenInfos.balances[i].normalizeAmount(IERC20Metadata(tokenInfos.tokens[i]).decimals());
        }

        IBasePool.SwapRequest memory request = IBasePool.SwapRequest({
            kind: IBasePool.SwapKind.EXACT_IN,
            tokenScaled18Amount: tokenScaled18Amount,
            tokenInIndex: tokenIndexIn,
            tokenOutIndex: tokenIndexOut,
            scaled18Amount: tokenAmountIn.normalizeAmount(IERC20Metadata(tokenInfos.tokens[tokenIndexIn]).decimals())
        });

        IBasePool pool = IBasePool(_pool);
        uint256 scaled18AmountOut = pool.onSwap(request);
        
        tokenAmountOut = scaled18AmountOut.denormalizeAmount(IERC20Metadata(tokenInfos.tokens[tokenIndexOut]).decimals());

        poolTokenBalances[_pool][address(tokenOut)] += tokenAmountOut;
        poolTokenBalances[_pool][address(tokenIn)] -= tokenAmountIn;

        emit Swap(_pool, address(tokenIn), address(tokenOut), tokenAmountIn, tokenAmountOut);

        return tokenAmountOut;
    }

    function _singleSwapExactOut(
        address _pool,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 tokenAmountOut
    ) internal poolLived(_pool) returns (uint256 tokenAmountIn) {
        PoolTokenInfo memory tokenInfos = getPoolTokens(_pool);
        IERC20 tokenIn = IERC20(tokenInfos.tokens[tokenIndexIn]);
        IERC20 tokenOut = IERC20(tokenInfos.tokens[tokenIndexOut]);
        
        uint256[] memory tokenScaled18Amount = new uint256[](tokenInfos.tokens.length);
        for (uint256 i = 0; i < tokenInfos.tokens.length; i++) {
            tokenScaled18Amount[i] = tokenInfos.balances[i].normalizeAmount(IERC20Metadata(tokenInfos.tokens[i]).decimals());
        }

        IBasePool.SwapRequest memory request = IBasePool.SwapRequest({
            kind: IBasePool.SwapKind.EXACT_OUT,
            tokenScaled18Amount: tokenScaled18Amount,
            tokenInIndex: tokenIndexIn,
            tokenOutIndex: tokenIndexOut,
            scaled18Amount: tokenAmountOut.normalizeAmount(IERC20Metadata(tokenInfos.tokens[tokenIndexOut]).decimals())
        });

        IBasePool pool = IBasePool(_pool);
        uint256 scaled18AmountIn = pool.onSwap(request);
        
        tokenAmountIn = scaled18AmountIn.denormalizeAmount(IERC20Metadata(tokenInfos.tokens[tokenIndexIn]).decimals());

        poolTokenBalances[_pool][address(tokenOut)] += tokenAmountOut;
        poolTokenBalances[_pool][address(tokenIn)] -= tokenAmountIn;

        emit Swap(_pool, address(tokenIn), address(tokenOut), tokenAmountIn, tokenAmountOut);

        return tokenAmountIn;
    }

}