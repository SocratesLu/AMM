pragma solidity ^0.8.0;

interface IVault {
    function registerPool(address pool, address[] memory tokens) external;
    function isPoolRegistered(address pool) external view returns (bool);
    function getPoolTokensData(address pool) external view returns (address[] memory tokens, uint256[] memory balances);
}
