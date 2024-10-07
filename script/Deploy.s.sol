// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {WeightedPoolFactory} from "../src/WeightedPool/WeightedPoolFactory.sol";
import {WeightedPool} from "../src/WeightedPool/WeightedPool.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {WETH9} from "../src/mocks/WETH9.sol";
import {MockToken} from "../test/Context.t.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // 部署WETH
        WETH9 weth = new WETH9();

        // 部署Vault逻辑合约
        Vault vaultImplementation = new Vault(address(weth));

        // 部署透明代理
        bytes memory initData = abi.encodeWithSelector(Vault.initialize.selector, deployer);
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImplementation), initData);
        Vault vault = Vault(payable(address(vaultProxy)));

        // 部署WeightedPoolFactory
        WeightedPoolFactory factory = new WeightedPoolFactory(address(vault));
        vault.addFactory(address(factory));

        // 部署MockTokens
        MockToken tokenA = new MockToken("Token A", "TKA");
        MockToken tokenB = new MockToken("Token B", "TKB");

        // 创建权重数组
        uint256[] memory weights = new uint256[](3);
        weights[0] = 1e17; // 10%
        weights[1] = 4e17; // 40%
        weights[2] = 5e17; // 50%

        // 创建代币数组
        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE); // ETH_ADDRESS

        // 创建池子
        WeightedPool pool = WeightedPool(factory.createPool(tokens, weights, 3e15)); // 0.3% swap fee

        vm.stopBroadcast();

        // 输出部署的合约地址
        console.log("WETH deployed at:", address(weth));
        console.log("Vault Proxy deployed at:", address(vault));
        console.log("WeightedPoolFactory deployed at:", address(factory));
        console.log("Token A deployed at:", address(tokenA));
        console.log("Token B deployed at:", address(tokenB));
        console.log("WeightedPool deployed at:", address(pool));
    }
}
