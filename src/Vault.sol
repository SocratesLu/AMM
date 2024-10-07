pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./interfaces/IWETH.sol";
import {VaultFunding} from "./VaultFunding.sol";
import {VaultSwap} from "./VaultSwap.sol";
import {IVault} from "./interfaces/IVault.sol";
import {VaultStorage} from "./VaultStorage.sol";   
import "forge-std/Test.sol";


contract Vault is IVault, Ownable2Step, VaultFunding, VaultSwap {
    mapping(address => bool) public authorizedFactories;

    event FactoryAdded(address indexed factory);
    event FactoryRemoved(address indexed factory);

    error UnauthorizedFactory();
    error PoolAlreadyRegistered();

    modifier onlyAuthorizedFactory() {
        if (!authorizedFactories[msg.sender]) revert UnauthorizedFactory();
        _;
    }

    constructor(address _weth) Ownable(msg.sender) {
        globalPause = false;
        WETH = IWETH(_weth);
    }

    // =================== Owner functions ========================

    function setGlobalPause(bool _pause) external onlyOwner {
        globalPause = _pause;
    }

    function setPoolLock(address _pool, bool _lock) external onlyOwner {
        poolLocks[_pool] = _lock;
    }

    function addFactory(address factory) external onlyOwner {
        authorizedFactories[factory] = true;
        emit FactoryAdded(factory);
    }

    function removeFactory(address factory) external onlyOwner {
        authorizedFactories[factory] = false;
        emit FactoryRemoved(factory);
    }

    // =================== Factory create pools ========================

    function registerPool(address pool, address[] memory tokens) external override onlyAuthorizedFactory {
        if (poolRegistered[pool]) revert PoolAlreadyRegistered();
        
        poolRegistered[pool] = true;
        poolTokens[pool] = tokens;  
        for (uint256 i = 0; i < tokens.length; i++) {
            poolTokenBalances[pool][tokens[i]] = 0;
        }
    }

    // =================== Read functions ========================
    function isPoolRegistered(address pool) external view override returns (bool) {
        return poolRegistered[pool];
    }

    function getPoolTokensData(address pool) external view override returns (address[] memory tokens, uint256[] memory balances) {
        PoolTokenInfo memory poolInfo = getPoolTokens(pool);
        console.log("tokenlen", poolInfo.tokens.length);
        console.log("balanceslen", poolInfo.balances.length);
        return (poolInfo.tokens, poolInfo.balances);
    }

}