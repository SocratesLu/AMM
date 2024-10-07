// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library NormalizeAmount {
    function normalizeAmount(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals > 18) return amount / (10**(decimals - 18));
        return amount * (10**(18 - decimals));
    }

    function denormalizeAmount(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        if (decimals == 18) return amount;
        if (decimals > 18) return amount * (10**(decimals - 18));
        return amount / (10**(18 - decimals));
    }
}   