// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IWETH.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IVaultStructs.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "forge-std/Test.sol";

contract VaultStorage is ReentrancyGuard, IVaultStructs {
    IWETH public immutable WETH;
    address public constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    struct PoolTokenInfo {
        address[] tokens;
        uint256[] balances;
    }

    bool public globalPause;
    mapping(address => bool) public poolRegistered;
    mapping(address => bool) public poolLocks;
    mapping(address => address[]) public poolTokens;
    mapping(address => mapping(address => uint256)) public poolTokenBalances;

    event Swap(address indexed pool, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event LiquidityAdded(address indexed pool, address indexed user, uint256 lpTokens);
    event LiquidityRemoved(address indexed pool, address indexed user, uint256 lpTokens);

    error GlobalPauseActive();
    error PoolUnavailable();
    error AmountLengthMismatch();
    error DeadlineExpired();
    error EmptySwapPath();
    error InsufficientOutputAmount();
    error TooManySwaps();
    error InsufficientInputAmount();
    error InsufficientETHSent();
    error ETHRefundFailed();
    error ETHTransferFailed();

    modifier notPaused() {
        if (globalPause) revert GlobalPauseActive();
        _;
    }

    modifier poolLived(address _pool) {
        if (poolLocks[_pool] || !poolRegistered[_pool]) revert PoolUnavailable();
        _;
    }

    receive() external payable {
        assert(msg.sender == address(WETH)); // only accept ETH via fallback from the WETH contract
    }

    function getPoolTokens(address pool) public view returns (PoolTokenInfo memory poolInfo) {
        poolInfo.tokens = poolTokens[pool];

        uint256[] memory tmpBalances = new uint256[](poolInfo.tokens.length);
        for (uint256 i = 0; i < poolInfo.tokens.length; i++) {
            tmpBalances[i] = poolTokenBalances[pool][poolInfo.tokens[i]];
        }   
        poolInfo.balances = tmpBalances;
    }
}