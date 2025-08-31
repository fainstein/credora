// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ICredoraShares
 * @author Credora Protocol
 * @notice Interface for CRD Shares - proof of ownership for lender deposits
 * @dev Represents lender's share of the lending pool that appreciates with yield.
 * CRD tokens are minted on deposits, always backed by wstETH in Symbiotic vault.
 * Share price increases with network security rewards.
 */
interface ICredoraShares {
    /// @notice Errors
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error UnauthorizedAccess();

    /// @notice Events
    event SharesMinted(
        address indexed to,
        uint256 shares,
        uint256 assets,
        uint256 sharePrice
    );

    // TODO: Add burn and yield events for future withdrawals
    // event SharesBurned(address indexed from, uint256 shares, uint256 assets, uint256 sharePrice);
    // event YieldAdded(address indexed source, uint256 yieldAmount, uint256 newSharePrice);

    /**
     * @notice Mint CRD shares to lender
     * @dev Only callable by Pool contract during deposits.
     * @param to Recipient address
     * @param amount Amount of CRD shares to mint
     */
    function mint(address to, uint256 amount) external;

    // TODO: Implement burn function for future withdrawals
    // function burn(address from, uint256 amount) external;

    /**
     * @notice Get the current CRD share price using real-time wstETH balance
     * @dev Queries Pool for current yield provider balance, gets CRD supply,
     * then calls calculatePrice() for final computation.
     * @return price Current price in 18 decimals (wstETH per CRD)
     */
    function sharePrice() external view returns (uint256 price);

    /**
     * @notice Calculate CRD price given current wstETH balance and CRD supply
     * @dev Pure mathematical calculation for price determination.
     * Used by Pool to compute real-time prices without external dependencies.
     * @param totalWstETHBalance Current wstETH balance in yield provider (18 decimals)
     * @param totalCRDSupply Current total CRD supply
     * @return price Calculated price (18 decimals)
     */
    function calculatePrice(
        uint256 totalWstETHBalance,
        uint256 totalCRDSupply
    ) external pure returns (uint256 price);

    /**
     * @notice Calculate CRD shares to mint for a wstETH deposit
     * @dev Uses current share price to determine fair mint amount.
     * More wstETH deposited = more CRD shares minted at current price.
     * @param wstETHAmount Amount of wstETH being deposited (18 decimals)
     * @return shares Number of CRD shares to mint
     */
    function calculateSharesForDeposit(uint256 wstETHAmount) external view returns (uint256 shares);

    // TODO: Implement share redemption calculations for future withdrawals
    // function calculateWstETHForShares(uint256 shares) external view returns (uint256 wstETHAmount);

    // TODO: Implement total assets tracking for future withdrawals
    // function totalPoolAssets() external view returns (uint256 assets);

    // TODO: Implement pool assets tracking for future withdrawals
    // function updatePoolAssets(uint256 newTotal) external;

    // TODO: Implement yield tracking for future withdrawals
    // function addYield(uint256 yieldAmount) external;

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
     * @notice Get the pool contract address
     * @return pool Address of the Pool contract
     */
    function getPool() external view returns (address pool);
}
