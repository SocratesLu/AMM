# Simple AMM with Vault-Pool Structure

## Part 1: Introduction

This project implements a simple Automated Market Maker (AMM) with a vault-pool structure. To accommodate multi-token trading requirements, the pool utilizes Balancer's algorithm. The system is designed with future scalability in mind, allowing for potential iterations to support multiple pool types.

Key features:
- Vault-pool architecture for enhanced security and flexibility
- Multi-token support using Balancer's weighted pool algorithm
- Upgradeable design for future improvements

## Part 2: Contract Structure

The AMM consists of three main components:

1. **Vault**: 
   - Acts as the central hub for all funds
   - Serves as the entry point for user transactions
   - Manages global system parameters and security features

2. **Pool**: 
   - Implements trading algorithm logic
   - Handles LP token minting and burning
   - Calculates swap amounts and fees

3. **PoolFactory**: 
   - Enables permissionless creation of new pools
   - Registers newly created pools with the Vault
   - Manages pool deployment and initialization

## Part 3: Contract Methods

### Vault Methods

#### User Methods:
1. `swapExactIn(SwapParams memory params) external payable returns (uint256)`
   - Performs a token swap with an exact input amount
   - Supports multi-hop swaps (up to 3 hops)

2. `swapExactOut(SwapParams memory params) external payable returns (uint256)`
   - Performs a token swap with an exact output amount
   - Supports multi-hop swaps (up to 3 hops)

3. `addLiquidity(address _pool, uint256[] memory amounts, uint256 minToMint, uint256 deadline) external payable returns (uint256)`
   - Adds liquidity to a specified pool
   - Returns the amount of LP tokens minted

4. `removeLiquidity(address _pool, uint256 lpTokenAmount, uint256[] memory minAmountsOut, uint256 deadline) external returns (uint256[] memory)`
   - Removes liquidity from a specified pool
   - Returns the amounts of tokens received

#### Admin Methods:
1. `setGlobalPause(bool _pause) external onlyOwner`
   - Pauses or unpauses all operations in the Vault

2. `setPoolLock(address _pool, bool _lock) external onlyOwner`
   - Locks or unlocks a specific pool

3. `addFactory(address factory) external onlyOwner`
   - Adds a new authorized factory

4. `removeFactory(address factory) external onlyOwner`
   - Removes an authorized factory

note: The operation to delete the pool is not currently provided, considering that the pool does not manage funds independently, and therefore should not be deleted by the admin.

## Part 4: Forge Test Usage

To run tests using Forge:

1. Install Forge if you haven't already:
   ```
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. Install dependencies:
   ```
   forge install
   ```

3. Run tests:
   ```
   forge test
   ```

For more information on Forge and its features, refer to the [Forge Book](https://book.getfoundry.sh/).