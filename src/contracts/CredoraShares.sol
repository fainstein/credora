// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICredoraShares} from "../interfaces/ICredoraShares.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPool} from "../interfaces/IPool.sol";

/**
 * @title CredoraShares
 * @dev ERC20 token representing CRD shares in the lending pool
 * Implements price calculation based on wstETH balance growth
 */
contract CredoraShares is ERC20, Ownable {
    IPool public immutable pool;

    // Errors
    error ZeroAddress();
    error ZeroAmount();
    error UnauthorizedAccess();

    // Events
    event SharesMinted(
        address indexed to,
        uint256 shares,
        uint256 assets,
        uint256 sharePrice
    );

    constructor(address _pool) ERC20("Credora Shares", "CRD") Ownable(msg.sender) {
        if (_pool == address(0)) revert ZeroAddress();
        pool = IPool(_pool);
    }

    /**
     * @notice Mint CRD shares to lender
     * @dev Only callable by Pool contract during deposits
     */
    function mint(address to, uint256 amount) external {
        if (msg.sender != address(pool)) revert UnauthorizedAccess();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 currentPrice = sharePrice();
        _mint(to, amount);

        emit SharesMinted(to, amount, 0, currentPrice); // assets = 0 for now
    }

    /**
     * @notice Get the current CRD share price using real-time wstETH balance
     * @dev Price = total_wstETH_balance / total_CRD_supply
     * Initially 1:1, grows as wstETH balance increases with yield
     */
    function sharePrice() public view returns (uint256 price) {
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) return 1e18; // Initial 1:1 ratio

        uint256 wstETHBalance = pool.getWstETHBalance();
        return calculatePrice(wstETHBalance, totalSupply);
    }

    /**
     * @notice Calculate CRD price given current wstETH balance and CRD supply
     * @dev Pure mathematical calculation: price = wstETH_balance / CRD_supply
     */
    function calculatePrice(
        uint256 totalWstETHBalance,
        uint256 totalCRDSupply
    ) public pure returns (uint256 price) {
        if (totalCRDSupply == 0) return 1e18; // Prevent division by zero
        if (totalWstETHBalance == 0) return 1e18; // Initial state

        // Price = wstETH_balance * 1e18 / CRD_supply
        return (totalWstETHBalance * 1e18) / totalCRDSupply;
    }

    /**
     * @notice Calculate CRD shares to mint for a wstETH deposit
     * @dev Uses current share price: shares = wstETH_amount / current_price
     */
    function calculateSharesForDeposit(uint256 wstETHAmount) external view returns (uint256 shares) {
        if (wstETHAmount == 0) revert ZeroAmount();

        uint256 currentPrice = sharePrice();
        if (currentPrice == 0) return wstETHAmount; // Fallback to 1:1

        // shares = wstETH_amount * 1e18 / current_price
        return (wstETHAmount * 1e18) / currentPrice;
    }

    /**
     * @notice Get the pool contract address
     */
    function getPool() external view returns (address) {
        return address(pool);
    }
}
