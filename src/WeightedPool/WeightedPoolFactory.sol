// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import {WeightedPool} from "./WeightedPool.sol";
import "../interfaces/IVault.sol";

contract WeightedPoolFactory is Ownable2Step {
    IVault public immutable vault;

    event PoolCreated(address indexed creator, address indexed pool, address[] tokens);

    mapping(address => address[]) public creatorPools;

    error InvalidWeights();
    error InvalidSwapFee();
    error InvalidTokens();
    error PoolAlreadyExists();

    constructor(address _vault) Ownable(msg.sender) {
        vault = IVault(_vault);
    }

    function createPool(
        address[] memory tokens,
        uint256[] memory weights,
        uint256 swapFee
    ) external returns (address pool) {
        if (weights.length < 2 || weights.length > 8) revert InvalidWeights();
        if (swapFee > 1e17) revert InvalidSwapFee();
        if (tokens.length != weights.length) revert InvalidTokens();

        bytes32 salt = keccak256(abi.encode(tokens, weights, swapFee));

        bytes memory bytecode = abi.encodePacked(
            type(WeightedPool).creationCode,
            abi.encode(address(vault), weights, swapFee)
        );

        // Predict the pool address
        address predictedAddress = Create2.computeAddress(salt, keccak256(bytecode));

        // Check if the pool already exists
        if (vault.isPoolRegistered(predictedAddress)) revert PoolAlreadyExists();

        // Deploy the pool
        pool = Create2.deploy(0, salt, bytecode);

        creatorPools[msg.sender].push(pool);
        emit PoolCreated(msg.sender, pool, tokens);

        vault.registerPool(pool, tokens);
    }

    function getCreatorPools(address creator) external view returns (address[] memory) {
        return creatorPools[creator];
    }

    // Function to predict pool address (optional, for frontend or other contracts)
    function predictPoolAddress(
        address[] memory tokens,
        uint256[] memory weights,
        uint256 swapFee
    ) public view returns (address) {
        bytes32 salt = keccak256(abi.encode(tokens, weights, swapFee));
        bytes memory bytecode = abi.encodePacked(
            type(WeightedPool).creationCode,
            abi.encode(address(vault), weights, swapFee)
        );
        return Create2.computeAddress(salt, keccak256(bytecode));
    }
}
