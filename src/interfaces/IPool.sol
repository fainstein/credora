// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IPool
 * @author Credora Protocol
 * @notice Main liquidity pool for wstETH deposits
 * @dev Handles ETH deposits (converted to wstETH), interacts with Symbiotic vaults,
 * manages advance payments from borrowers. Only deposits, no withdrawals.
 *
 * Deposit Flow:
 * 1. User sends ETH to pool
 * 2. Pool converts ETH to wstETH (via Lido)
 * 3. Pool deposits wstETH to Symbiotic vault
 * 4. Vault delegates stake to operators providing network security
 * 5. Pool mints CRD shares proportional to wstETH deposited
 * 6. CRD tokens are deposited in CRDVault
 *
 * Yield Accumulation:
 * - wstETH in Symbiotic earns rewards from network security payments
 * - CRD tokens appreciate as Symbiotic vault balance grows
 * - No withdrawals needed - users hold appreciating CRD tokens
 */
interface IPool {
    /// @notice Errors
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error UnauthorizedAccess();
    error InvalidAmount();
    error TransferFailed();
    error DepositFailed();
    error NoSharesMinted();

    /// @notice Events
    event Deposit(
        address indexed user,
        uint256 ethAmount,
        uint256 wstETHAmount,
        uint256 crdShares
    );

    event ReceivePayment(
        address indexed from,
        uint256 ethAmount,
        uint256 wstETHAmount
    );

    event WstETHDeposited(
        address indexed symbioticVault,
        uint256 wstETHAmount,
        uint256 sharesMinted
    );

    /**
     * @notice Deposit ETH into the pool
     * @dev Takes ETH from user and follows the Symbiotic deposit flow:
     * 1. Send ETH to stETH.submit() to receive stETH
     * 2. Approve stETH to wstETH contract
     * 3. Call wstETH.wrap() to receive wstETH
     * 4. Approve wstETH to Symbiotic vault
     * 5. Call vault.deposit() to stake wstETH
     * 6. Mint equivalent CRD shares proportional to wstETH deposited
     * @return crdShares Amount of CRD shares minted
     */
    function deposit() external payable returns (uint256 crdShares);

    /**
     * @notice Receive advance payments from borrowers
     * @dev Called when borrowers make loan payments or initial deposits.
     * Only accepts ETH (converts to wstETH via Symbiotic flow), then sends to Symbiotic vault.
     * Follows the same deposit flow: ETH → stETH → wstETH → vault deposit.
     * @param from Borrower address
     * @param amount Amount of ETH received (18 decimals)
     */
    function receivePayment(
        address from,
        uint256 amount
    ) external payable;

    /**
     * @notice Get current wstETH balance in Symbiotic vault
     * @dev Returns current wstETH balance deposited in Symbiotic vault.
     * This includes principal + accumulated rewards from network security payments.
     * @return wstETHBalance Current wstETH balance (18 decimals)
     */
    function getWstETHBalance() external view returns (uint256 wstETHBalance);

    /**
     * @notice Get the CredoraShares contract address
     * @return credoraShares Address of the CredoraShares contract
     */
    function getCredoraSharesAddress() external view returns (address credoraShares);

    /**
     * @notice Get stETH contract address
     * @return stETH Address of the Lido stETH contract
     */
    function getStETHAddress() external pure returns (address stETH);

    /**
     * @notice Get wstETH contract address
     * @return wstETH Address of the Lido wstETH contract
     */
    function getWstETHAddress() external pure returns (address wstETH);

    /**
     * @notice Get Symbiotic vault contract address
     * @return symbioticVault Address of the Symbiotic vault contract
     */
    function getSymbioticVaultAddress() external pure returns (address symbioticVault);

    /**
     * @notice Get current CRD share price
     * @return price Current price in wstETH per CRD (18 decimals)
     */
    function getCRDPrice() external view returns (uint256 price);

    /**
     * @notice Calculate CRD shares for wstETH deposit
     * @param wstETHAmount Amount of wstETH to deposit
     * @return shares Number of CRD shares to mint
     */
    function calculateCRDShares(uint256 wstETHAmount) external view returns (uint256 shares);

    /**
     * @notice Get CRD price per share
     * @return price Price in wstETH per CRD (18 decimals)
     */
    function getCRDPricePerShare() external view returns (uint256 price);
}
