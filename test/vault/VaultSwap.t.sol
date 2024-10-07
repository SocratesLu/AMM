pragma solidity ^0.8.0;

import "../Context.t.sol";
import {IVault} from "../../src/interfaces/IVault.sol";
import {IVaultStructs} from "../../src/interfaces/IVaultStructs.sol";

contract VaultSwapTest is Context, IVaultStructs {
    address public bob = address(3);
    MockToken public tokenD;
    WeightedPool public poolETHD;


    function setUp() public {
        createAll();
        vm.deal(bob, 20 ether);
        tokenA.mint(bob, 100e18);
        tokenB.mint(bob, 100e18);
    }

    function test_SwapAForBExactIn() public {
        vm.startPrank(bob);
        tokenA.approve(address(vault), type(uint256).max);

        uint256 bobInitialB = tokenB.balanceOf(bob);

        IVaultStructs.SingleSwap[] memory swaps = new IVaultStructs.SingleSwap[](1);
        swaps[0] = IVaultStructs.SingleSwap({
            pool: address(pool),
            tokenIndexIn: 0,
            tokenIndexOut: 1
        });

        IVaultStructs.SwapParams memory params = IVaultStructs.SwapParams({
            swaps: swaps,
            tokenAmountIn: 5e18,
            minAmountOut: 0,
            deadline: block.timestamp + 1000,
            user: bob
        });

        uint256 amountOut = vault.swapExactIn(params);
        console.log("amountOut", amountOut);
        
        assertGt(amountOut, 0, "Swap output should be greater than 0");
        assertEq(tokenB.balanceOf(bob) - bobInitialB, amountOut, "Bob should receive the correct amount of token B");

        vm.stopPrank();
    }

    function test_SwapAForETHExactIn() public {
        vm.startPrank(bob);
        tokenA.approve(address(vault), type(uint256).max);

        uint256 bobInitialETH = bob.balance;

        IVaultStructs.SingleSwap[] memory swaps = new IVaultStructs.SingleSwap[](1);
        swaps[0] = IVaultStructs.SingleSwap({
            pool: address(pool),
            tokenIndexIn: 0,
            tokenIndexOut: 2
        });

        IVaultStructs.SwapParams memory params = IVaultStructs.SwapParams({
            swaps: swaps,
            tokenAmountIn: 5e18,
            minAmountOut: 0,
            deadline: block.timestamp + 1000,
            user: bob
        });

        uint256 amountOut = vault.swapExactIn(params);
        console.log("amountOut", amountOut);
        
        assertGt(amountOut, 0, "Swap output should be greater than 0");
        assertEq(bob.balance - bobInitialETH, amountOut, "Bob should receive the correct amount of ETH");

        vm.stopPrank();
    }

    function test_SwapETHForAExactIn() public {
        vm.startPrank(bob);

        uint256 bobInitialA = tokenA.balanceOf(bob);

        IVaultStructs.SingleSwap[] memory swaps = new IVaultStructs.SingleSwap[](1);
        swaps[0] = IVaultStructs.SingleSwap({
            pool: address(pool),
            tokenIndexIn: 2,
            tokenIndexOut: 0
        });

        IVaultStructs.SwapParams memory params = IVaultStructs.SwapParams({
            swaps: swaps,
            tokenAmountIn: 1e18,
            minAmountOut: 0,
            deadline: block.timestamp + 1000,
            user: bob
        });

        uint256 amountOut = vault.swapExactIn{value: 1e18}(params);
        console.log("amountOut", amountOut);
        
        assertGt(amountOut, 0, "Swap output should be greater than 0");
        assertEq(tokenA.balanceOf(bob) - bobInitialA, amountOut, "Bob should receive the correct amount of token A");

        vm.stopPrank();
    }

    function test_SwapAForDViaTwoHopsExactIn() public {
        // Create new pool with ETH and token D
        vm.startPrank(alice);
        tokenD = new MockToken("Token D", "TKD");
        tokenD.mint(alice, 1000e18);

        uint256[] memory weightsETHD = new uint256[](2);
        weightsETHD[0] = 5e17; // 50%
        weightsETHD[1] = 5e17; // 50%

        address[] memory tokensETHD = new address[](2);
        tokensETHD[0] = ETH_ADDRESS;
        tokensETHD[1] = address(tokenD);

        poolETHD = WeightedPool(factory.createPool(tokensETHD, weightsETHD, 3e15)); // 0.3% swap fee

        // Add initial liquidity to the new pool
        tokenD.approve(address(vault), type(uint256).max);
        uint256[] memory amountsETHD = new uint256[](2);
        amountsETHD[0] = 5e18; // 5 ETH
        amountsETHD[1] = 100e18; // 100 Token D
        vault.addLiquidity{value: 5 ether}(address(poolETHD), amountsETHD, 0, block.timestamp + 100);
        vm.stopPrank();

        // Bob swaps A for D via two hops
        vm.startPrank(bob);
        tokenA.approve(address(vault), type(uint256).max);

        uint256 bobInitialD = tokenD.balanceOf(bob);

        IVaultStructs.SingleSwap[] memory swaps = new IVaultStructs.SingleSwap[](2);
        swaps[0] = IVaultStructs.SingleSwap({
            pool: address(pool),
            tokenIndexIn: 0,
            tokenIndexOut: 2
        });
        swaps[1] = IVaultStructs.SingleSwap({
            pool: address(poolETHD),
            tokenIndexIn: 0,
            tokenIndexOut: 1
        });

        IVaultStructs.SwapParams memory params = IVaultStructs.SwapParams({
            swaps: swaps,
            tokenAmountIn: 5e18,
            minAmountOut: 0,
            deadline: block.timestamp + 1000,
            user: bob
        });

        uint256 amountOut = vault.swapExactIn(params);
        console.log("amountOut", amountOut);
        
        assertGt(amountOut, 0, "Swap output should be greater than 0");
        assertEq(tokenD.balanceOf(bob) - bobInitialD, amountOut, "Bob should receive the correct amount of token D");

        vm.stopPrank();
    }

    // ============== Exact Out =============

    function test_SwapAForBExactOut() public {
        vm.startPrank(bob);
        tokenA.approve(address(vault), type(uint256).max);

        uint256 bobInitialB = tokenB.balanceOf(bob);
        uint256 exactOutAmount = 4e18; // Exact amount of B token Bob wants to receive

        IVaultStructs.SingleSwap[] memory swaps = new IVaultStructs.SingleSwap[](1);
        swaps[0] = IVaultStructs.SingleSwap({
            pool: address(pool),
            tokenIndexIn: 0,
            tokenIndexOut: 1
        });

        IVaultStructs.SwapParams memory params = IVaultStructs.SwapParams({
            swaps: swaps,
            tokenAmountIn: type(uint256).max, // Set to max as we don't know the exact input amount
            minAmountOut: exactOutAmount,
            deadline: block.timestamp + 1000,
            user: bob
        });

        uint256 amountIn = vault.swapExactOut(params);
        console.log("Amount of A token spent:", amountIn);
        
        assertGt(amountIn, 0, "Swap input should be greater than 0");
        assertEq(tokenB.balanceOf(bob) - bobInitialB, exactOutAmount, "Bob should receive the exact amount of token B");

        vm.stopPrank();
    }

    function test_SwapAForETHExactOut() public {
        vm.startPrank(bob);
        tokenA.approve(address(vault), type(uint256).max);

        uint256 bobInitialETH = bob.balance;
        uint256 exactOutAmount = 0.5e18; // Exact amount of ETH Bob wants to receive

        IVaultStructs.SingleSwap[] memory swaps = new IVaultStructs.SingleSwap[](1);
        swaps[0] = IVaultStructs.SingleSwap({
            pool: address(pool),
            tokenIndexIn: 0,
            tokenIndexOut: 2
        });

        IVaultStructs.SwapParams memory params = IVaultStructs.SwapParams({
            swaps: swaps,
            tokenAmountIn: type(uint256).max, // Set to max as we don't know the exact input amount
            minAmountOut: exactOutAmount,
            deadline: block.timestamp + 1000,
            user: bob
        });

        uint256 amountIn = vault.swapExactOut(params);
        console.log("Amount of A token spent:", amountIn);
        
        assertGt(amountIn, 0, "Swap input should be greater than 0");
        assertEq(bob.balance - bobInitialETH, exactOutAmount, "Bob should receive the exact amount of ETH");

        vm.stopPrank();
    }

    function test_SwapETHForAExactOut() public {
        vm.startPrank(bob);

        uint256 bobInitialA = tokenA.balanceOf(bob);
        uint256 exactOutAmount = 10e18; // Exact amount of A token Bob wants to receive

        IVaultStructs.SingleSwap[] memory swaps = new IVaultStructs.SingleSwap[](1);
        swaps[0] = IVaultStructs.SingleSwap({
            pool: address(pool),
            tokenIndexIn: 2,
            tokenIndexOut: 0
        });

        IVaultStructs.SwapParams memory params = IVaultStructs.SwapParams({
            swaps: swaps,
            tokenAmountIn: type(uint256).max, // Set to max as we don't know the exact input amount
            minAmountOut: exactOutAmount,
            deadline: block.timestamp + 1000,
            user: bob
        });

        uint256 amountIn = vault.swapExactOut{value: 2e18}(params); // Send more ETH than needed
        console.log("Amount of ETH spent:", amountIn);
        
        assertGt(amountIn, 0, "Swap input should be greater than 0");
        assertEq(tokenA.balanceOf(bob) - bobInitialA, exactOutAmount, "Bob should receive the exact amount of token A");

        vm.stopPrank();
    }

    function test_SwapAForDViaTwoHopsExactOut() public {
        // Create new pool with ETH and token D (same as in ExactIn test)
        vm.startPrank(alice);
        tokenD = new MockToken("Token D", "TKD");
        tokenD.mint(alice, 1000e18);

        uint256[] memory weightsETHD = new uint256[](2);
        weightsETHD[0] = 5e17; // 50%
        weightsETHD[1] = 5e17; // 50%

        address[] memory tokensETHD = new address[](2);
        tokensETHD[0] = ETH_ADDRESS;
        tokensETHD[1] = address(tokenD);

        poolETHD = WeightedPool(factory.createPool(tokensETHD, weightsETHD, 3e15)); // 0.3% swap fee

        // Add initial liquidity to the new pool
        tokenD.approve(address(vault), type(uint256).max);
        uint256[] memory amountsETHD = new uint256[](2);
        amountsETHD[0] = 5e18; // 5 ETH
        amountsETHD[1] = 100e18; // 100 Token D
        vault.addLiquidity{value: 5 ether}(address(poolETHD), amountsETHD, 0, block.timestamp + 100);
        vm.stopPrank();

        // Bob swaps A for D via two hops
        vm.startPrank(bob);
        tokenA.approve(address(vault), type(uint256).max);

        uint256 bobInitialD = tokenD.balanceOf(bob);
        uint256 exactOutAmount = 1e18; // Exact amount of D token Bob wants to receive

        IVaultStructs.SingleSwap[] memory swaps = new IVaultStructs.SingleSwap[](2);
        swaps[0] = IVaultStructs.SingleSwap({
            pool: address(pool),
            tokenIndexIn: 0,
            tokenIndexOut: 2
        });
        swaps[1] = IVaultStructs.SingleSwap({
            pool: address(poolETHD),
            tokenIndexIn: 0,
            tokenIndexOut: 1
        });

        IVaultStructs.SwapParams memory params = IVaultStructs.SwapParams({
            swaps: swaps,
            tokenAmountIn: type(uint256).max, // Set to max as we don't know the exact input amount
            minAmountOut: exactOutAmount,
            deadline: block.timestamp + 1000,
            user: bob
        });

        uint256 amountIn = vault.swapExactOut(params);
        console.log("Amount of A token spent:", amountIn);
        
        assertGt(amountIn, 0, "Swap input should be greater than 0");
        assertEq(tokenD.balanceOf(bob) - bobInitialD, exactOutAmount, "Bob should receive the exact amount of token D");

        vm.stopPrank();
    }

}