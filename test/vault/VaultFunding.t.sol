pragma solidity ^0.8.0;

import "../Context.t.sol";

contract VaultFundingTest is Context {
    address public bob = address(3);

    function setUp() public {
        createAll();
        vm.deal(bob, 100 ether);
        tokenA.mint(bob, 1000e18);
        tokenB.mint(bob, 1000e18);
    }

    function testAddLiquidityAllTokens() public {
        vm.startPrank(bob);
        
        tokenA.approve(address(vault), type(uint256).max);
        tokenB.approve(address(vault), type(uint256).max);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 5e18; // 5 Token A
        amounts[1] = 5e18; // 5 Token B
        amounts[2] = 0.5e18; // 0.5 ETH

        uint256 lpTokensBefore = pool.balanceOf(bob);
        vault.addLiquidity{value: 0.5 ether}(address(pool), amounts, 0, block.timestamp + 100);
        uint256 lpTokensAfter = pool.balanceOf(bob);

        uint256 lpTokensReceived = lpTokensAfter - lpTokensBefore;

        console.log("Case 1 - Bob's LP tokens received:", lpTokensReceived);
        console.log("weth balance", weth.balanceOf(address(vault)));

        vm.stopPrank();
    }

    function testAddLiquidityOnlyETH() public {
        vm.startPrank(bob);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 0; // 0 Token A
        amounts[1] = 0; // 0 Token B
        amounts[2] = 0.5e18; // 0.5 ETH

        uint256 lpTokensBefore = pool.balanceOf(bob);
        vault.addLiquidity{value: 0.5 ether}(address(pool), amounts, 0, block.timestamp + 100);
        uint256 lpTokensAfter = pool.balanceOf(bob);

        uint256 lpTokensReceived = lpTokensAfter - lpTokensBefore;

        console.log("Case 2 - Bob's LP tokens received:", lpTokensReceived);

        vm.stopPrank();
    }

    function testRemoveLiquidityAllTokens() public {
        testAddLiquidityAllTokens();

        vm.startPrank(bob);

        uint256 lpTokens = pool.balanceOf(bob);
        pool.approve(address(vault), lpTokens);

        (uint256[] memory amountsOut) = vault.removeLiquidity(address(pool), lpTokens, new uint256[](3), block.timestamp + 100);

        console.log("Case 3 - Bob's tokens received:");
        console.log("Token A:", amountsOut[0]);
        console.log("Token B:", amountsOut[1]);
        console.log("ETH:", amountsOut[2]);

        vm.stopPrank();
    }

    function testRemoveLiquidityOnlyETH() public {
        testAddLiquidityOnlyETH();

        vm.startPrank(bob);

        uint256 lpTokens = pool.balanceOf(bob);
        pool.approve(address(vault), lpTokens);

        (uint256[] memory amountsOut) = vault.removeLiquidity(address(pool), lpTokens, new uint256[](3), block.timestamp + 100);

        console.log("Case 4 - Bob's tokens received:");
        console.log("Token A:", amountsOut[0]);
        console.log("Token B:", amountsOut[1]);
        console.log("ETH:", amountsOut[2]);

        vm.stopPrank();
    }
}
