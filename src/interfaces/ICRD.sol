// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ICRD
 * @author Credora Protocol
 * @notice Interface for the CRD token contract
 * @dev ERC20 token representing shares in the lending pool.
 * Initially backed 1:1 by wstETH, appreciates as wstETH balance grows with yield.
 */
interface ICRD {
    /**
     * @notice Mint CRD tokens
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external;

    /**
     * @notice Burn CRD tokens
     * @param from Account to burn from
     * @param amount Amount to burn
     */
    function burn(address from, uint256 amount) external;

    /// @notice Errors
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error UnauthorizedAccess();

    /// @notice Events
    event CRDMinted(
        address indexed to,
        uint256 amount,
        uint256 sharePrice
    );

    event CRDBurned(
        address indexed from,
        uint256 amount,
        uint256 sharePrice
    );

    /**
     * @notice Get total CRD supply
     * @return supply Total CRD tokens in circulation
     */
    function totalSupply() external view returns (uint256 supply);

    /**
     * @notice Get CRD balance of an account
     * @param account Account address
     * @return balance CRD balance
     */
    function balanceOf(address account) external view returns (uint256 balance);

    /**
     * @notice Get the current share price (wstETH per CRD)
     * @dev Price increases as wstETH balance grows with network security rewards.
     * @return price Current price in 18 decimals (wstETH per CRD)
     */
    function getPricePerShare() external view returns (uint256 price);

    /**
     * @notice Get the pool contract address
     * @return pool Address of the Pool contract
     */
    function getPool() external view returns (address pool);

    /**
     * @notice Get the CRD vault contract address
     * @return vault Address of the CRD Vault contract
     */
    function getCRDVault() external view returns (address vault);
}
