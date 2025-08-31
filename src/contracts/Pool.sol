// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPool} from "../interfaces/IPool.sol";
import {ICredoraShares} from "../interfaces/ICredoraShares.sol";
import {CredoraShares} from "./CredoraShares.sol";
import "../interfaces/IExternal.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Pool
 * @dev Main liquidity pool for wstETH deposits using Symbiotic
 */
contract Pool is IPool {
    using SafeERC20 for IERC20;

    ICredoraShares public immutable credoraShares;

    // Sepolia testnet contract addresses
    address public constant STETH = 0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af;
    address public constant WSTETH = 0xB82381A3fBD3FaFA77B3a7bE693342618240067b;
    address public constant SYMBIOTIC_VAULT =
        0x77F170Dcd0439c0057055a6D7e5A1Eb9c48cCD2a;

    uint256 private _totalWstETHBalance;

    modifier validAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    modifier validAddress(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }

    constructor(address _credoraShares) {
        if (_credoraShares == address(0)) {
            // Create CredoraShares automatically
            CredoraShares newCredoraShares = new CredoraShares(address(this));
            credoraShares = ICredoraShares(address(newCredoraShares));
        } else {
            // Use provided CredoraShares address (already validated as non-zero by else condition)
            credoraShares = ICredoraShares(_credoraShares);
        }
    }

    /**
     * @notice Deposit ETH and receive CRD shares
     * @dev Follows Symbiotic deposit flow:
     * 1. Convert ETH to wstETH via _depositEthToSymbiotic()
     * 2. Mint CRD shares proportional to wstETH deposited
     * 3. Deposit CRD tokens to CRD vault (TODO)
     */
    function deposit()
        external
        payable
        validAmount(msg.value)
        returns (uint256 crdShares)
    {
        uint256 ethAmount = msg.value;

        // Convert ETH to wstETH and deposit to Symbiotic vault
        uint256 wstETHAmount = _depositEthToSymbiotic(msg.sender, ethAmount);

        // Mint CRD shares proportional to wstETH deposited
        crdShares = credoraShares.calculateSharesForDeposit(wstETHAmount);
        credoraShares.mint(msg.sender, crdShares);

        // TODO: Deposit CRD tokens to CRD vault
        // _depositCRDToVault(msg.sender, crdShares);

        emit Deposit(msg.sender, ethAmount, wstETHAmount, crdShares);
    }

    /**
     * @dev Helper function that abstracts the complete ETH → wstETH → Symbiotic vault flow
     * @param depositor Address making the deposit
     * @param ethAmount Amount of ETH to deposit
     * @return wstETHAmount Amount of wstETH deposited to vault
     */
    function _depositEthToSymbiotic(
        address depositor,
        uint256 ethAmount
    ) internal returns (uint256 wstETHAmount) {
        // Step 1: Send ETH to stETH.submit() to receive stETH
        uint256 stETHAmount = IStETH(STETH).submit{value: ethAmount}(
            address(0)
        );

        // Step 2: Approve stETH to wstETH contract
        IStETH(STETH).approve(WSTETH, stETHAmount);

        // Step 3: Call wstETH.wrap() to convert stETH to wstETH
        uint256 wstETHBeforeWrap = IWstETH(WSTETH).balanceOf(address(this));
        uint256 wstETHFromWrap = IWstETH(WSTETH).wrap(stETHAmount);
        uint256 wstETHAfterWrap = IWstETH(WSTETH).balanceOf(address(this));

        // Use the actual wstETH balance increase for deposit
        uint256 actualWstETHReceived = wstETHAfterWrap - wstETHBeforeWrap;

        // For testing compatibility, use the wrap return value as primary amount
        // This handles mock scenarios where balance tracking is difficult
        uint256 depositAmount = wstETHFromWrap > 0
            ? wstETHFromWrap
            : actualWstETHReceived;
        if (depositAmount == 0) revert ZeroAmount();

        // Step 4: Approve wstETH to Symbiotic vault
        IWstETH(WSTETH).approve(SYMBIOTIC_VAULT, depositAmount);

        // Step 5: Call vault.deposit() to stake wstETH
        (uint256 depositedAmount, uint256 mintedShares) = ISymbioticVault(
            SYMBIOTIC_VAULT
        ).deposit(depositor, depositAmount);

        if (depositedAmount == 0) revert DepositFailed();
        if (mintedShares == 0) revert NoSharesMinted();

        // Update total balance
        _totalWstETHBalance += depositedAmount;

        emit WstETHDeposited(SYMBIOTIC_VAULT, depositedAmount, mintedShares);

        return depositAmount;
    }

    /**
     * @notice Receive advance payments from borrowers
     * @dev Only accepts ETH (converts to wstETH via Symbiotic flow), follows same deposit flow
     */
    function receivePayment(
        address from,
        uint256 amount
    ) external payable validAddress(from) validAmount(amount) {
        require(msg.value == amount, "ETH amount mismatch");

        uint256 ethAmount = amount;

        // Convert ETH to wstETH and deposit to Symbiotic vault
        uint256 wstETHAmount = _depositEthToSymbiotic(from, ethAmount);

        emit ReceivePayment(from, ethAmount, wstETHAmount);
    }

    /**
     * @notice Get current wstETH balance deposited in Symbiotic vault
     * @dev Returns the balance of wstETH staked in the Symbiotic vault
     */
    function getWstETHBalance() external view returns (uint256) {
        return ISymbioticVault(SYMBIOTIC_VAULT).balanceOf(address(this));
    }

    /**
     * @notice Get the CredoraShares contract address
     */
    function getCredoraSharesAddress() external view returns (address) {
        return address(credoraShares);
    }

    /**
     * @notice Get current CRD share price
     * @return price Current price in wstETH per CRD (18 decimals)
     */
    function getCRDPrice() external view returns (uint256 price) {
        return credoraShares.sharePrice();
    }

    /**
     * @notice Calculate CRD shares for wstETH deposit
     * @param wstETHAmount Amount of wstETH to deposit
     * @return shares Number of CRD shares to mint
     */
    function calculateCRDShares(
        uint256 wstETHAmount
    ) external view returns (uint256 shares) {
        return credoraShares.calculateSharesForDeposit(wstETHAmount);
    }

    /**
     * @notice Get CRD price per share
     * @return price Price in wstETH per CRD (18 decimals)
     */
    function getCRDPricePerShare() external view returns (uint256 price) {
        return credoraShares.sharePrice();
    }

    /**
     * @notice Get stETH contract address
     */
    function getStETHAddress() external pure returns (address) {
        return STETH;
    }

    /**
     * @notice Get wstETH contract address
     */
    function getWstETHAddress() external pure returns (address) {
        return WSTETH;
    }

    /**
     * @notice Get Symbiotic vault contract address
     */
    function getSymbioticVaultAddress() external pure returns (address) {
        return SYMBIOTIC_VAULT;
    }
}
