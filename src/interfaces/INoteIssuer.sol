// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVerifier} from "./IVerifier.sol";

/**
 * @title INoteIssuer
 * @author Credora Protocol
 * @notice Factory contract for creating and managing promissory notes
 * @dev ERC1155 factory that creates notes for borrowers, handles repayments,
 * and manages note lifecycle. Interacts with Pool for advance payments
 * and CRDVault for CRD token management.
 */
interface INoteIssuer {
    /// @notice Note status enumeration
    enum NoteStatus {
        Active,
        Repaid,
        Defaulted
    }

    /// @notice Note data structure
    struct Note {
        address borrower;
        uint256 principalAmount;    // Original loan amount (18 decimals)
        uint256 advanceAmount;      // Advance payment (20% of loan, 18 decimals for wstETH)
        uint256 interestRate;       // Annual interest rate (basis points)
        uint256 maturity;           // Maturity timestamp
        uint256 createdAt;          // Creation timestamp
        NoteStatus status;
    }

    /// @notice Errors
    error InvalidProof();
    error InsufficientAdvance();
    error AmountTooHigh();
    error ZeroAddress();
    error ZeroAmount();

    /// @notice Events
    event NoteCreated(
        address indexed borrower,
        uint256 indexed noteId,
        uint256 principalAmount,
        uint256 advanceAmount,
        address indexed creditor
    );

    event RepaymentMade(
        address indexed borrower,
        uint256 indexed noteId,
        uint256 amount,
        uint256 remainingDebt
    );

    event NoteRepaid(
        address indexed borrower,
        uint256 indexed noteId
    );

    event NoteDefaulted(
        address indexed borrower,
        uint256 indexed noteId
    );

    /**
     * @notice Create a new promissory note
     * @dev Validates proof, checks advance payment requirements, creates ERC1155 note,
     * accepts ETH (converts to wstETH) for advance payment (20% of loan), transfers to pool.
     * @param amount Loan amount requested (18 decimals, max 5 wstETH)
     * @param advanceAmount Advance payment to provide (20% of loan amount)
     * @param _pA The proof's A point [x, y]
     * @param _pB The proof's B point [[x1, x2], [y1, y2]]
     * @param _pC The proof's C point [x, y]
     * @param _pubSignals The public signals array (5 elements)
     * @param creditor Address to receive the note (optional, defaults to borrower)
     * @return noteId ID of the created note
     */
    function createNote(
        uint256 amount,
        uint256 advanceAmount,
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[5] calldata _pubSignals,
        address creditor
    ) external payable returns (uint256 noteId);

    /**
     * @notice Make a repayment on a note
     * @dev Accepts ETH (converts to wstETH via pool), transfers to pool, updates note balances.
     * If overpayment, only charges remaining debt.
     * @param noteId ID of the note to repay
     * @param amount Amount to repay (18 decimals)
     * @return actualRepayment Actual amount charged
     * @return remainingDebt Remaining debt after repayment
     */
    function repay(
        uint256 noteId,
        uint256 amount
    ) external payable returns (uint256 actualRepayment, uint256 remainingDebt);

    /**
     * @notice Redeem a note for its wstETH equivalent
     * @dev Called by note holder to cash out. Transfers CRD back to vault,
     * calculates wstETH equivalent, and sends wstETH to redeemer.
     * @param noteId ID of the note to redeem
     * @param redeemer Address to receive wstETH
     * @return wstETHAmount Amount of wstETH received
     */
    function redeemNote(
        uint256 noteId,
        address redeemer
    ) external returns (uint256 wstETHAmount);

    /**
     * @notice Get CRD balance of a note
     * @param noteId ID of the note
     * @return balance CRD balance held by the note
     */
    function getNoteCRDBalance(uint256 noteId) external view returns (uint256 balance);

    /**
     * @notice Get total payments made on a note
     * @param noteId ID of the note
     * @return totalPaid Total wstETH paid (18 decimals)
     */
    function getNoteTotalPaid(uint256 noteId) external view returns (uint256 totalPaid);

    /**
     * @notice Get remaining debt on a note
     * @param noteId ID of the note
     * @return remainingDebt Remaining debt (18 decimals)
     */
    function getNoteRemainingDebt(uint256 noteId) external view returns (uint256 remainingDebt);

    /**
     * @notice Get note data
     * @param noteId ID of the note
     * @return note Complete note data
     */
    function getNote(uint256 noteId) external view returns (Note memory note);

    /**
     * @notice Check if a note is mature
     * @param noteId ID of the note
     * @return isMature True if note has reached maturity
     */
    function isNoteMature(uint256 noteId) external view returns (bool isMature);

    /**
     * @notice Calculate required advance payment for loan amount
     * @param loanAmount Loan amount (18 decimals)
     * @return advanceRequired Required advance payment (18 decimals)
     */
    function calculateRequiredAdvance(uint256 loanAmount) external view returns (uint256 advanceRequired);

    /**
     * @notice Get maximum allowed loan amount
     * @return maxAmount Maximum loan amount in wstETH (18 decimals)
     */
    function getMaxLoanAmount() external view returns (uint256 maxAmount);

    /**
     * @notice Get advance payment ratio (basis points)
     * @return ratio Advance payment ratio (e.g., 2000 = 20%)
     */
    function getAdvanceRatio() external view returns (uint256 ratio);

    /**
     * @notice Get the verifier contract
     * @return verifier Address of the verifier contract
     */
    function getVerifier() external view returns (IVerifier verifier);

    /**
     * @notice Get the pool contract
     * @return pool Address of the pool contract
     */
    function getPool() external view returns (address pool);

    /**
     * @notice Get the CRD vault contract
     * @return vault Address of the CRD vault contract
     */
    function getCRDVault() external view returns (address vault);

    /**
     * @notice Transfer ownership of a note
     * @param noteId ID of the note
     * @param newOwner New owner address
     */
    function transferNote(uint256 noteId, address newOwner) external;
}
