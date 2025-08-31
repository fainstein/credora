// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {INoteIssuer} from "../interfaces/INoteIssuer.sol";
import {ICreditNote721} from "../interfaces/ICreditNote721.sol";
import {IPool} from "../interfaces/IPool.sol";
import {ICRDVault} from "../interfaces/ICRDVault.sol";
import {IVerifier} from "../interfaces/IVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title NoteIssuer
 * @dev Factory contract for creating and managing promissory notes
 * Implements ERC-721 note creation with CRD token backing via internal escrow
 */
contract NoteIssuer is INoteIssuer {
    using SafeERC20 for IERC20;

    // Immutable contract references
    ICreditNote721 public immutable note;
    IPool public immutable pool;
    ICRDVault public immutable crdVault;
    IVerifier public immutable verifier;

    // Configuration constants
    uint256 public constant MAX_LOAN_AMOUNT = 5 ether; // 5 wstETH max loan

    // Additional errors (not in interfaces)
    error NoteNotFound();
    error NoteNotActive();
    error UnauthorizedAccess();
    error InvalidAmount();

    // State variables
    uint256 private _nextNoteId = 1;
    mapping(uint256 => Note) private _notes;
    mapping(uint256 => uint256) private _noteTotalPaid;
    mapping(uint256 => uint256) private _noteCRDBalance;
    mapping(uint256 => uint256) private _noteTokenIds; // Maps noteId to ERC-721 tokenId

    // Advance payment requirements
    uint256 public constant ADVANCE_RATIO = 2000; // 20% advance payment required (basis points)

    // Events (already declared in interface)

    modifier validAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    modifier validAddress(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }

    modifier onlyBorrower(uint256 noteId) {
        if (_notes[noteId].borrower != msg.sender) revert UnauthorizedAccess();
        _;
    }

    modifier noteExists(uint256 noteId) {
        if (_notes[noteId].borrower == address(0)) revert NoteNotFound(); // Note doesn't exist
        _;
    }

    modifier noteActive(uint256 noteId) {
        if (_notes[noteId].status != NoteStatus.Active) revert NoteNotActive();
        _;
    }

    constructor(
        address _note,
        address _pool,
        address _crdVault,
        address _verifier
    ) validAddress(_note) validAddress(_pool) validAddress(_crdVault) validAddress(_verifier) {
        note = ICreditNote721(_note);
        pool = IPool(_pool);
        crdVault = ICRDVault(_crdVault);
        verifier = IVerifier(_verifier);
    }

    /**
     * @notice Create a new promissory note
     */
    function createNote(
        uint256 amount,
        uint256 advanceAmount,
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[5] calldata _pubSignals,
        address creditor
    ) external payable validAmount(amount) returns (uint256 noteId) {
        // Validate proof
        bool isValid = verifier.verifyProof(_pA, _pB, _pC, _pubSignals);
        if (!isValid) revert InvalidProof();

        // Validate loan amount
        if (amount > MAX_LOAN_AMOUNT) revert AmountTooHigh();

        // Calculate required advance (20% of loan amount)
        uint256 requiredAdvance = _calculateRequiredAdvance(amount);
        if (advanceAmount < requiredAdvance) revert InsufficientAdvance();

        // Validate ETH amount matches advance
        if (msg.value != advanceAmount) revert InvalidAmount();

        // Set creditor (default to msg.sender if not provided)
        address actualCreditor = creditor == address(0) ? msg.sender : creditor;

        // Deposit advance to pool (converts to wstETH)
        pool.receivePayment{value: advanceAmount}(msg.sender, advanceAmount);

        // Calculate note value in wstETH (loan + advance)
        uint256 noteValueWstETH = amount + advanceAmount;

        // Calculate CRD tokens equivalent to note value
        uint256 crdTokensEquivalent = pool.calculateCRDShares(noteValueWstETH);

        // Transfer existing CRD tokens from vault to CreditNote721
        // These CRD tokens were minted when Alice deposited to the pool
        crdVault.transferCRDToNote(address(note), noteId, crdTokensEquivalent);

        // Create note with ERC-721 + internal escrow
        noteId = _nextNoteId++;
        _notes[noteId] = Note({
            borrower: msg.sender,
            principalAmount: amount,
            advanceAmount: advanceAmount,
            interestRate: 500, // 5% fixed for now
            maturity: block.timestamp + 365 days,
            createdAt: block.timestamp,
            status: NoteStatus.Active
        });

        // Mint ERC-721 note with CRD deposit in one transaction
        // This creates the NFT and deposits CRD tokens internally
        uint256 tokenId = note.mintWithDeposit(
            actualCreditor,
            crdTokensEquivalent,
            msg.sender, // borrower
            amount, // principalAmount
            advanceAmount, // advanceAmount
            500, // interestRate (5% in basis points)
            block.timestamp + 365 days // maturity (1 year from now)
        );

        // Store the ERC-721 tokenId for this note
        _noteTokenIds[noteId] = tokenId;

        emit NoteCreated(msg.sender, noteId, amount, advanceAmount, actualCreditor);
    }

    /**
     * @notice Make a repayment on a note
     */
    function repay(
        uint256 noteId,
        uint256 amount
    ) external payable validAmount(amount) noteExists(noteId) noteActive(noteId) onlyBorrower(noteId) returns (uint256 actualRepayment, uint256 remainingDebt) {
        Note storage noteData = _notes[noteId];

        // Validate ETH amount
        if (msg.value != amount) revert InvalidAmount();

        // Calculate remaining debt
        uint256 currentDebt = _calculateNoteRemainingDebt(noteId);

        // Handle overpayments
        actualRepayment = amount > currentDebt ? currentDebt : amount;
        remainingDebt = currentDebt - actualRepayment;

        // Update paid amount
        _noteTotalPaid[noteId] += actualRepayment;

        // Deposit payment to pool
        pool.receivePayment{value: actualRepayment}(msg.sender, actualRepayment);

        // Check if note is fully repaid
        if (remainingDebt == 0) {
            noteData.status = NoteStatus.Repaid;
            emit NoteRepaid(msg.sender, noteId);
        }

        emit RepaymentMade(msg.sender, noteId, actualRepayment, remainingDebt);
    }

    /**
     * @notice Redeem a note for its wstETH equivalent
     * @dev TODO: Implement redemption logic for future withdrawals
     */
    function redeemNote(
        uint256 /* noteId */,
        address /* redeemer */
    ) external pure returns (uint256 wstETHAmount) {
        // TODO: Implement redemption logic
        // This will involve burning CRD tokens and returning wstETH equivalent
        revert("Not implemented yet");
    }



    /**
     * @notice Get total payments made on a note
     */
    function getNoteTotalPaid(uint256 noteId) external view noteExists(noteId) returns (uint256 totalPaid) {
        return _noteTotalPaid[noteId];
    }



    /**
     * @dev Internal function to calculate remaining debt
     */
    function _calculateNoteRemainingDebt(uint256 noteId) internal view returns (uint256) {
        Note memory noteData = _notes[noteId];
        uint256 totalPaid = _noteTotalPaid[noteId];
        return noteData.principalAmount > totalPaid ? noteData.principalAmount - totalPaid : 0;
    }

    /**
     * @notice Get note data
     */
    function getNote(uint256 noteId) external view noteExists(noteId) returns (Note memory) {
        return _notes[noteId];
    }

    /**
     * @notice Check if a note is mature
     */
    function isNoteMature(uint256 noteId) external view noteExists(noteId) returns (bool isMature) {
        return block.timestamp >= _notes[noteId].maturity;
    }

    /**
     * @notice Calculate required advance payment for loan amount
     */
    function calculateRequiredAdvance(uint256 loanAmount) external pure returns (uint256 advanceRequired) {
        return _calculateRequiredAdvance(loanAmount);
    }

    /**
     * @dev Internal function to calculate required advance
     */
    function _calculateRequiredAdvance(uint256 loanAmount) internal pure returns (uint256) {
        return (loanAmount * ADVANCE_RATIO) / 10000; // ADVANCE_RATIO is in basis points
    }

    /**
     * @notice Get maximum allowed loan amount
     */
    function getMaxLoanAmount() external pure returns (uint256 maxAmount) {
        return MAX_LOAN_AMOUNT;
    }

    /**
     * @notice Get advance payment ratio (basis points)
     */
    function getAdvanceRatio() external pure returns (uint256 ratio) {
        return ADVANCE_RATIO;
    }

    /**
     * @notice Get the verifier contract
     */
    function getVerifier() external view returns (IVerifier) {
        return verifier;
    }

    /**
     * @notice Get the pool contract
     */
    function getPool() external view returns (address) {
        return address(pool);
    }

    /**
     * @notice Get the CRD vault contract
     */
    function getCRDVault() external view returns (address) {
        return address(crdVault);
    }

    /**
     * @notice Transfer ownership of a note
     * @dev This would typically be handled by the ERC-721 note contract
     */
    function transferNote(uint256 /* noteId */, address /* newOwner */) external pure {
        // Note transfers are handled by the ERC-721 note contract
        // This function might be used for additional bookkeeping
        revert("Use ERC-721 transfer functions instead");
    }

    /**
     * @notice Get the ERC-721 tokenId for a note
     * @param noteId Note ID
     * @return tokenId ERC-721 token ID
     */
    function getNoteTokenId(uint256 noteId) external view returns (uint256 tokenId) {
        if (_notes[noteId].borrower == address(0)) revert NoteNotFound();
        return _noteTokenIds[noteId];
    }

    /**
     * @notice Get CRD balance of a note (from ERC-721 internal escrow)
     * @param noteId Note ID
     * @return balance CRD balance in the ERC-721 token
     */
    function getNoteCRDBalance(uint256 noteId) external view returns (uint256 balance) {
        if (_notes[noteId].borrower == address(0)) revert NoteNotFound();
        uint256 tokenId = _noteTokenIds[noteId];
        return note.balanceOfStable(tokenId);
    }

    /**
     * @notice Check if a note's debt is fully paid
     * @param noteId Note ID
     * @return isPaid True if amountBorrowed - amountRepaid == 0
     */
    function isNoteDebtPaid(uint256 noteId) external view returns (bool isPaid) {
        if (_notes[noteId].borrower == address(0)) revert NoteNotFound();
        Note storage noteData = _notes[noteId];
        return noteData.principalAmount <= _noteTotalPaid[noteId];
    }

    /**
     * @notice Get remaining debt for a note
     * @param noteId Note ID
     * @return remainingDebt Amount still owed (principal - paid)
     */
    function getNoteRemainingDebt(uint256 noteId) external view returns (uint256 remainingDebt) {
        if (_notes[noteId].borrower == address(0)) revert NoteNotFound();
        Note storage noteData = _notes[noteId];
        if (noteData.principalAmount <= _noteTotalPaid[noteId]) {
            return 0;
        }
        return noteData.principalAmount - _noteTotalPaid[noteId];
    }
}
