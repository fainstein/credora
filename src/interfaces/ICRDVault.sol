// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ICRDVault
 * @author Credora Protocol
 * @notice Vault that holds all minted CRD tokens from pool deposits
 * @dev Manages CRD token supply, handles minting/burning operations,
 * and provides approvals for NoteIssuer to transfer CRD when creating notes.
 * All CRD tokens are backed by USDC in the pool.
 */
interface ICRDVault {
    /// @notice Errors
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientBalance();
    error UnauthorizedAccess();
    error InvalidAmount();

    /// @notice Events
    event CRDMinted(
        address indexed to,
        uint256 amount
    );

    event CRDBurned(
        address indexed from,
        uint256 amount
    );

    event NoteIssuerApproved(
        address indexed noteIssuer,
        uint256 amount
    );

    event CRDTransferredToNote(
        address indexed noteIssuer,
        uint256 indexed noteId,
        uint256 amount
    );

    event CRDReturnedFromNote(
        address indexed from,
        uint256 indexed noteId,
        uint256 amount
    );

    /**
     * @notice Mint CRD tokens to a recipient
     * @dev Only callable by the Pool contract during deposits.
     * @param to Recipient address
     * @param amount Amount of CRD to mint
     */
    function mintCRD(address to, uint256 amount) external;

    /**
     * @notice Burn CRD tokens from a holder
     * @dev Only callable by the Pool contract during withdrawals.
     * @param from Holder address
     * @param amount Amount of CRD to burn
     */
    function burnCRD(address from, uint256 amount) external;

    /**
     * @notice Transfer CRD to NoteIssuer for note creation
     * @dev Called by NoteIssuer when creating a new note.
     * Transfers CRD from vault to NoteIssuer to fund the note.
     * @param noteIssuer Address of the NoteIssuer contract
     * @param noteId ID of the note being created
     * @param amount Amount of CRD to transfer
     */
    function transferCRDToNote(
        address noteIssuer,
        uint256 noteId,
        uint256 amount
    ) external;

    /**
     * @notice Return CRD from redeemed note to vault
     * @dev Called when a note is redeemed, returns CRD to vault.
     * @param from Address returning the CRD
     * @param noteId ID of the redeemed note
     * @param amount Amount of CRD returned
     */
    function returnCRDFromNote(
        address from,
        uint256 noteId,
        uint256 amount
    ) external;

    /**
     * @notice Set approval for NoteIssuer to transfer CRD
     * @dev Grants unlimited approval to NoteIssuer for CRD transfers.
     * @param noteIssuer Address of the NoteIssuer contract
     */
    function approveNoteIssuer(address noteIssuer) external;

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
     * @notice Get the CRD token contract address
     * @return crdToken Address of the CRD ERC20 token
     */
    function getCRDToken() external view returns (IERC20 crdToken);

    /**
     * @notice Check if address is authorized to mint/burn CRD
     * @param account Account to check
     * @return authorized True if account can mint/burn CRD
     */
    function isAuthorized(address account) external view returns (bool authorized);
}
