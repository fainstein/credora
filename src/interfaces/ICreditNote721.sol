// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

/**
 * @title ICreditNote721
 * @author Credora Protocol
 * @notice Interface for ERC-721 credit notes with internal escrow
 * @dev Each NFT holds CRD tokens internally, representing a debt obligation
 */
interface ICreditNote721 is IERC721, IERC721Metadata {
    /// @notice Credit note data structure
    struct CreditNoteData {
        address borrower;
        uint256 principalAmount;
        uint256 advanceAmount;
        uint256 interestRate; // in basis points (e.g., 500 = 5%)
        uint256 maturity;
        uint256 createdAt;
        uint256 totalPaid;
        NoteStatus status;
    }

    /// @notice Note status enum
    enum NoteStatus {
        Active,
        Repaid,
        Defaulted
    }

    /// @notice Errors
    error ZeroAddress();
    error ZeroAmount();
    error TokenNotFound();
    error InsufficientBalance();
    error NotOwner();
    error InvalidAmount();

    /// @notice Events
    event Minted(uint256 indexed tokenId, address indexed to, uint256 amount);
    event Deposited(uint256 indexed tokenId, address indexed depositor, uint256 amount);
    event Redeemed(uint256 indexed tokenId, address indexed redeemer, uint256 amount);

    /**
     * @notice Get CRD token contract
     * @return CRD token address
     */
    function stable() external view returns (address);

    /**
     * @notice Get CRD balance of a token
     * @param tokenId Token ID
     * @return CRD balance in smallest units
     */
    function balanceOfStable(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Get internal balance mapping
     * @param tokenId Token ID
     * @return CRD balance
     */
    function balanceOfToken(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Get next token ID to be minted
     * @return Next token ID
     */
    function nextId() external view returns (uint256);

    /**
     * @notice Get total CRD held by this contract
     * @return Total CRD balance
     */
    function totalCRDHeld() external view returns (uint256);

    /**
     * @notice Mint a new credit note with initial deposit
     * @param to Recipient of the NFT
     * @param amount CRD amount to deposit (in smallest units)
     * @param borrower Address of the borrower
     * @param principalAmount Principal loan amount in wstETH
     * @param advanceAmount Advance payment amount in wstETH
     * @param interestRate Interest rate in basis points (e.g., 500 = 5%)
     * @param maturity Timestamp when the note matures
     * @return tokenId The ID of the newly minted token
     */
    function mintWithDeposit(
        address to,
        uint256 amount,
        address borrower,
        uint256 principalAmount,
        uint256 advanceAmount,
        uint256 interestRate,
        uint256 maturity
    ) external returns (uint256 tokenId);

    /**
     * @notice Deposit CRD tokens to an existing note
     * @param tokenId Token ID to deposit to
     * @param amount CRD amount to deposit (in smallest units)
     */
    function deposit(uint256 tokenId, uint256 amount) external;

    /**
     * @notice Redeem a note by burning it and returning CRD to vault
     * @dev TODO/TBD: Not implemented in this version
     * @param tokenId Token ID to redeem
     */
    function redeem(uint256 tokenId) external;

    /**
     * @notice Get borrower of a credit note
     * @param tokenId Token ID
     * @return Borrower address
     */
    function getNoteBorrower(uint256 tokenId) external view returns (address);

    /**
     * @notice Get principal amount of a credit note
     * @param tokenId Token ID
     * @return Principal amount in wstETH
     */
    function getNotePrincipalAmount(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Get advance amount of a credit note
     * @param tokenId Token ID
     * @return Advance amount in wstETH
     */
    function getNoteAdvanceAmount(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Get interest rate of a credit note
     * @param tokenId Token ID
     * @return Interest rate in basis points
     */
    function getNoteInterestRate(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Get maturity timestamp of a credit note
     * @param tokenId Token ID
     * @return Maturity timestamp
     */
    function getNoteMaturity(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Get creation timestamp of a credit note
     * @param tokenId Token ID
     * @return Creation timestamp
     */
    function getNoteCreatedAt(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Get total paid amount of a credit note
     * @param tokenId Token ID
     * @return Total paid amount
     */
    function getNoteTotalPaid(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Get status of a credit note
     * @param tokenId Token ID
     * @return Note status
     */
    function getNoteStatus(uint256 tokenId) external view returns (NoteStatus);

    /**
     * @notice Check if a credit note is mature
     * @param tokenId Token ID
     * @return True if mature
     */
    function isNoteMature(uint256 tokenId) external view returns (bool);

    /**
     * @notice Get remaining debt of a credit note
     * @param tokenId Token ID
     * @return Remaining debt amount
     */
    function getNoteRemainingDebt(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Get credit note data
     * @param tokenId Token ID
     * @return Credit note data struct
     */
    function creditNoteData(uint256 tokenId) external view returns (CreditNoteData memory);

    /**
     * @notice Record payment made on a credit note
     * @dev Only callable by authorized contracts (like NoteIssuer)
     * @param tokenId Token ID of the note
     * @param paymentAmount Amount paid
     */
    function recordPayment(uint256 tokenId, uint256 paymentAmount) external;

    /**
     * @notice Update note status
     * @dev Only callable by authorized contracts (like NoteIssuer)
     * @param tokenId Token ID of the note
     * @param newStatus New status for the note
     */
    function updateNoteStatus(uint256 tokenId, NoteStatus newStatus) external;
}

/**
 * @title INoteIssuer
 * @author Credora Protocol
 * @notice Interface for NoteIssuer contract
 */
interface INoteIssuer {
    /**
     * @notice Check if a note's debt is fully paid
     * @param noteId Note ID
     * @return isPaid True if debt is fully paid
     */
    function isNoteDebtPaid(uint256 noteId) external view returns (bool isPaid);

    /**
     * @notice Get remaining debt for a note
     * @param noteId Note ID
     * @return remainingDebt Amount still owed
     */
    function getNoteRemainingDebt(uint256 noteId) external view returns (uint256 remainingDebt);

    /**
     * @notice Get the ERC-721 tokenId for a note
     * @param noteId Note ID
     * @return tokenId ERC-721 token ID
     */
    function getNoteTokenId(uint256 noteId) external view returns (uint256 tokenId);

    /**
     * @notice Get CRD balance of a note
     * @param noteId Note ID
     * @return balance CRD balance
     */
    function getNoteCRDBalance(uint256 noteId) external view returns (uint256 balance);
}
