pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IWETH.sol";
import {VaultFunding} from "./VaultFunding.sol";
import {VaultSwap} from "./VaultSwap.sol";
import {IVault} from "./interfaces/IVault.sol";
import {VaultStorage} from "./VaultStorage.sol";   
import "forge-std/Test.sol";

contract Vault is IVault, Initializable, Ownable2StepUpgradeable, UUPSUpgradeable, VaultFunding, VaultSwap {
    mapping(address => bool) public authorizedFactories;

    event FactoryAdded(address indexed factory);
    event FactoryRemoved(address indexed factory);

    error UnauthorizedFactory();
    error PoolAlreadyRegistered();

    modifier onlyAuthorizedFactory() {
        if (!authorizedFactories[msg.sender]) revert UnauthorizedFactory();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _weth) {
        WETH = IWETH(_weth);
        _disableInitializers();
    }

    function initialize(address _owner) public initializer {
        __Ownable2Step_init();
        __UUPSUpgradeable_init();
        _transferOwnership(_owner);  // 设置初始所有者
        globalPause = false;
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
        return (poolInfo.tokens, poolInfo.balances);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}