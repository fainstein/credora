// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title External Contract Interfaces
 * @dev Interfaces for external contracts used by Credora Protocol
 * Sepolia testnet addresses included for reference
 */

/**
 * @dev Interface for Lido stETH contract
 * Sepolia: 0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af
 */
interface IStETH {
    function submit(address _referral) external payable returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @dev Interface for Lido wstETH contract
 * Sepolia: 0xB82381A3fBD3FaFA77B3a7bE693342618240067b
 */
interface IWstETH {
    function wrap(uint256 _stETHAmount) external returns (uint256);
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function getWstETHByStETH(uint256 _stETHAmount) external view returns (uint256);
    function getStETHByWstETH(uint256 _wstETHAmount) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @dev Interface for Symbiotic vault
 * Sepolia: 0x77F170Dcd0439c0057055a6D7e5A1Eb9c48cCD2a
 */
interface ISymbioticVault {
    function deposit(address onBehalfOf, uint256 amount) external returns (uint256 depositedAmount, uint256 mintedShares);
    function balanceOf(address account) external view returns (uint256);
}
