// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IBasePool.sol";
import "./interfaces/IWETH.sol";
import "./lib/NormalizeAmount.sol";
import "./VaultStorage.sol";
import "forge-std/Test.sol";

contract VaultFunding is VaultStorage, Test {
    using SafeERC20 for IERC20;
    using NormalizeAmount for uint256;

    error InsufficientLPTokensMinted();

    function addLiquidity(
        address _pool,
        uint256[] memory amounts,
        uint256 minToMint,
        uint256 deadline
    ) external payable notPaused poolLived(_pool) nonReentrant returns (uint256 lpTokens) {
        if (block.timestamp > deadline) revert DeadlineExpired();

        IBasePool pool = IBasePool(_pool);
        PoolTokenInfo memory tokenInfos = getPoolTokens(_pool);
        uint256 ethAmount = 0;
        //console.log("token", tokenInfos.tokens[0]);

        {
        if (amounts.length != tokenInfos.tokens.length) revert AmountLengthMismatch();

        uint256[] memory scaled18Amounts = new uint256[](amounts.length);
        uint256[] memory scaled18Balances = new uint256[](amounts.length);

        for (uint256 i = 0; i < tokenInfos.tokens.length; i++) {
            address tokenAddress = tokenInfos.tokens[i];
            uint256 amount = amounts[i];

            if (tokenAddress == ETH_ADDRESS) {
                ethAmount += amount;
                tokenAddress = address(WETH); // Use WETH address for further processing
            }

            uint8 decimals = IERC20Metadata(tokenAddress).decimals();
            scaled18Amounts[i] = amount.normalizeAmount(decimals);
            scaled18Balances[i] = tokenInfos.balances[i].normalizeAmount(decimals);
        }

        IBasePool.LiquidityRequest memory request = IBasePool.LiquidityRequest({
            kind: IBasePool.LiquidityKind.ADD,
            tokenScaled18Amount: scaled18Balances,
            scaled18AmountIn: scaled18Amounts,
            lpTokenAmount: 0, // Not used for ADD
            user: msg.sender
        });

        lpTokens = pool.onAddLiquidity(request);

        if (lpTokens < minToMint) revert InsufficientLPTokensMinted();
        }

        // Transfer tokens and update balances

        for (uint256 i = 0; i < tokenInfos.tokens.length; i++) {
            address tokenAddress = tokenInfos.tokens[i];
            uint256 amount = amounts[i];
            if (amount == 0) continue;

            if (tokenAddress != ETH_ADDRESS) {
                IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
            }

            poolTokenBalances[_pool][tokenAddress] += amount;  // Update the balance in Vault storage
        }

        // Refund excess ETH if any
        if (msg.value > ethAmount) {
            (bool success, ) = msg.sender.call{value: msg.value - ethAmount}("");
            if (!success) revert ETHRefundFailed();
        }

        // Mint LP tokens
        pool.mintLPTokens(msg.sender, lpTokens);

        emit LiquidityAdded(_pool, msg.sender, lpTokens);

        return lpTokens;
    }

    function removeLiquidity(
        address _pool,
        uint256 lpTokenAmount,
        uint256[] memory minAmountsOut,
        uint256 deadline
    ) external notPaused poolLived(_pool) nonReentrant returns (uint256[] memory amounts) {
        if (block.timestamp > deadline) revert DeadlineExpired();

        IBasePool pool = IBasePool(_pool);
        PoolTokenInfo memory tokenInfos = getPoolTokens(_pool);

        {
        if (minAmountsOut.length != tokenInfos.tokens.length) revert AmountLengthMismatch();

        uint256[] memory scaled18Balances = new uint256[](tokenInfos.tokens.length);

        for (uint256 i = 0; i < tokenInfos.tokens.length; i++) {
            address tokenAddress = tokenInfos.tokens[i];
            uint8 decimals = tokenAddress == ETH_ADDRESS ? 18 : IERC20Metadata(tokenAddress).decimals();
            scaled18Balances[i] = tokenInfos.balances[i].normalizeAmount(decimals);
        }

        IBasePool.LiquidityRequest memory request = IBasePool.LiquidityRequest({
            kind: IBasePool.LiquidityKind.REMOVE,
            tokenScaled18Amount: scaled18Balances,
            scaled18AmountIn: new uint256[](tokenInfos.tokens.length), // Not used for REMOVE
            lpTokenAmount: lpTokenAmount,
            user: msg.sender
        });
        

        uint256[] memory scaled18AmountsOut = pool.onRemoveLiquidity(request);

        amounts = new uint256[](tokenInfos.tokens.length);
        for (uint256 i = 0; i < tokenInfos.tokens.length; i++) {
            address tokenAddress = tokenInfos.tokens[i];
            uint8 decimals = tokenAddress == ETH_ADDRESS ? 18 : IERC20Metadata(tokenAddress).decimals();
            amounts[i] = scaled18AmountsOut[i].denormalizeAmount(decimals);
            if (amounts[i] < minAmountsOut[i]) revert InsufficientOutputAmount();
        }
        
        }

        // Transfer LP tokens from user to vault
        IERC20(_pool).safeTransferFrom(msg.sender, address(this), lpTokenAmount);

        // Burn LP tokens
        pool.burnLPTokens(lpTokenAmount);
        

        // Transfer tokens to user and update balances
        for (uint256 i = 0; i < tokenInfos.tokens.length; i++) {
            address tokenAddress = tokenInfos.tokens[i];
            uint256 amount = amounts[i];
            if (amount == 0) continue;

            poolTokenBalances[_pool][tokenAddress] -= amount;  // Update the balance in Vault storage

            if (tokenAddress == ETH_ADDRESS) {
                (bool success, ) = msg.sender.call{value: amount}("");
                if (!success) revert ETHTransferFailed();
            } else {
                IERC20(tokenAddress).safeTransfer(msg.sender, amount);
            }
        }

        emit LiquidityRemoved(_pool, msg.sender, lpTokenAmount);

        return amounts;
    }
}