// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {WeightedPoolFactory} from "../src/WeightedPool/WeightedPoolFactory.sol";
import {WeightedPool} from "../src/WeightedPool/WeightedPool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IWETH} from "../src/interfaces/IWETH.sol";  
import {WETH9} from "../src/mocks/WETH9.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract Context is Test {
    Vault public vault;
    WeightedPoolFactory public factory;
    WeightedPool public pool;
    MockToken public tokenA;
    MockToken public tokenB;
    IWETH public weth;

    address public owner = address(1);
    address public alice = address(2);
    address public ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*
    function setUp() public {
        createAll();
    }
    */

    function createAll() public {
        vm.startPrank(owner);
        createVault();
        createWeightedPoolFactory();
        vm.stopPrank();

        vm.startPrank(alice);
        createPool();
        initialPool();
        vm.stopPrank();
    }

    function createVault() public {
        // 部署WETH
        weth = new WETH9();
        
        // 部署Vault逻辑合约
        Vault vaultImplementation = new Vault(address(weth));

        // 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            Vault.initialize.selector, 
            owner  // 设置owner为初始所有者
        );

        // 部署代理合约
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImplementation), initData);
        
        // 将代理合约地址转换为Vault接口
        vault = Vault(payable(address(vaultProxy)));
    }

    function createWeightedPoolFactory() public {
        factory = new WeightedPoolFactory(address(vault));
        vault.addFactory(address(factory));
    }

    function createPool() public {
        // 部署代币
        tokenA = new MockToken("Token A", "TKA");
        tokenB = new MockToken("Token B", "TKB");

        // 创建权重数组
        uint256[] memory weights = new uint256[](3);
        weights[0] = 1e17; // 10%
        weights[1] = 4e17; // 40%
        weights[2] = 5e17; // 50%

        // 创建代币数组
        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = ETH_ADDRESS;

        // 创建池子
        pool = WeightedPool(factory.createPool(tokens, weights, 3e15)); // 0.3% swap fee
        (address[] memory tokensPool, uint256[] memory balancesPool) = pool.getTokensData();
    }

    function initialPool() public {
        // 铸造代币给Alice
        tokenA.mint(alice, 100e18);
        tokenB.mint(alice, 100e18);
        
        // 给Alice一些ETH
        vm.deal(alice, 20 ether);

        // 授权Vault使用代币
        tokenA.approve(address(vault), type(uint256).max);
        tokenB.approve(address(vault), type(uint256).max);

        // 准备添加流动性的金额
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100e18; // 100 Token A
        amounts[1] = 100e18; // 100 Token B
        amounts[2] = 10e18;  // 10 ETH

        // 添加流动性
        vault.addLiquidity{value: 10 ether}(address(pool), amounts, 0, block.timestamp + 100);
    }

    function testSuccess() public {}
}
