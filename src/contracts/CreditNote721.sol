// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ICRDVault} from "../interfaces/ICRDVault.sol";

/**
 * @title CreditNote721
 * @author Credora Protocol
 * @notice ERC-721 contract representing credit notes with internal CRD escrow
 * @dev Each NFT holds CRD tokens internally as value representation mechanism.
 * CRD tokens serve as shares to calculate wstETH equivalent values between contracts.
 * Notes can be transferred between creditors but CRD tokens remain locked until debt redemption.
 */
contract CreditNote721 is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    /// @notice CRD token interface
    IERC20 public immutable stable;

    /// @notice CRD Vault interface
    ICRDVault public immutable crdVault;

    /// @notice Internal balance of CRD tokens per tokenId
    mapping(uint256 => uint256) public balanceOfToken;

    /// @notice Next token ID to mint
    uint256 private _nextId = 1;

    /// @notice Credit note data structure stored in NFT
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

    /// @notice Credit note data stored per tokenId
    mapping(uint256 => CreditNoteData) public creditNoteData;

    /// @notice Events
    event Minted(uint256 indexed tokenId, address indexed to, uint256 amount);
    event Deposited(uint256 indexed tokenId, address indexed depositor, uint256 amount);
    event Redeemed(uint256 indexed tokenId, address indexed redeemer, uint256 amount);

    /// @notice Errors
    error ZeroAddress();
    error ZeroAmount();
    error TokenNotFound();
    error InsufficientBalance();
    error NotOwner();
    error InvalidAmount();

    /**
     * @notice Constructor
     * @param stableToken CRD token contract address
     * @param crdVaultAddr CRD Vault contract address
     * @param initialOwner Initial owner of the contract
     */
    constructor(IERC20 stableToken, address crdVaultAddr, address initialOwner)
        ERC721("Credora Credit Note", "CCN")
        Ownable(initialOwner)
    {
        if (address(stableToken) == address(0)) revert ZeroAddress();
        if (crdVaultAddr == address(0)) revert ZeroAddress();
        if (initialOwner == address(0)) revert ZeroAddress();
        stable = stableToken;
        crdVault = ICRDVault(crdVaultAddr);
    }

    /**
     * @notice Mint a new credit note with initial deposit
     * @dev Requires prior approval of CRD tokens to this contract
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
    )
        external
        nonReentrant
        returns (uint256 tokenId)
    {
        if (to == address(0)) revert ZeroAddress();
        if (borrower == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        // CRD tokens are already in this contract (transferred by CRDVault)

        // Mint NFT
        tokenId = _nextId++;
        _mint(to, tokenId);

        // Set internal balance
        balanceOfToken[tokenId] = amount;

        // Store credit note data in storage
        creditNoteData[tokenId] = CreditNoteData({
            borrower: borrower,
            principalAmount: principalAmount,
            advanceAmount: advanceAmount,
            interestRate: interestRate,
            maturity: maturity,
            createdAt: block.timestamp,
            totalPaid: 0,
            status: NoteStatus.Active
        });

        // Generate and set token URI with metadata from storage
        _setTokenURI(tokenId, _buildTokenURI(tokenId));

        emit Minted(tokenId, to, amount);
    }

    /**
     * @notice Deposit CRD tokens to an existing note
     * @dev Anyone can deposit to any existing note
     * @param tokenId Token ID to deposit to
     * @param amount CRD amount to deposit (in smallest units)
     */
    function deposit(uint256 tokenId, uint256 amount)
        external
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();

        // Transfer CRD tokens from sender to this contract
        stable.safeTransferFrom(msg.sender, address(this), amount);

        // Update internal balance
        balanceOfToken[tokenId] += amount;

        emit Deposited(tokenId, msg.sender, amount);
    }

    /**
     * @notice Record payment made on a credit note
     * @dev Only callable by authorized contracts (like NoteIssuer)
     * @param tokenId Token ID of the note
     * @param paymentAmount Amount paid
     */
    function recordPayment(uint256 tokenId, uint256 paymentAmount) external {
        // TODO: Add access control - only NoteIssuer should be able to call this
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();

        creditNoteData[tokenId].totalPaid += paymentAmount;

        // Check if note is fully repaid
        CreditNoteData storage data = creditNoteData[tokenId];
        if (data.principalAmount <= data.totalPaid && data.status == NoteStatus.Active) {
            data.status = NoteStatus.Repaid;
        }
    }

    /**
     * @notice Update note status
     * @dev Only callable by authorized contracts (like NoteIssuer)
     * @param tokenId Token ID of the note
     * @param newStatus New status for the note
     */
    function updateNoteStatus(uint256 tokenId, NoteStatus newStatus) external {
        // TODO: Add access control - only NoteIssuer should be able to call this
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();

        creditNoteData[tokenId].status = newStatus;

        // Update token URI to reflect new status
        _setTokenURI(tokenId, _buildTokenURI(tokenId));
    }

    /**
     * @notice Redeem a note by burning it and returning CRD to vault
     * @dev TODO/TBD: Not implemented in this version
     */
    function redeem(uint256 /* tokenId */) external pure {
        // TODO: Implement redemption logic
        // This would involve:
        // 1. Burning the NFT
        // 2. Returning CRD tokens to vault
        // 3. Withdrawing wstETH from Symbiotic
        // 4. Converting wstETH to ETH and sending to creditor
        revert("Redeem not implemented in this version");
    }

    /**
     * @notice Get CRD balance of a token
     * @param tokenId Token ID
     * @return CRD balance in smallest units
     */
    function balanceOfStable(uint256 tokenId) external view returns (uint256) {
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();
        return balanceOfToken[tokenId];
    }

    /**
     * @notice Get next token ID to be minted
     * @return Next token ID
     */
    function nextId() external view returns (uint256) {
        return _nextId;
    }

    /**
     * @notice Get total CRD held by this contract
     * @return Total CRD balance
     */
    function totalCRDHeld() external view returns (uint256) {
        return stable.balanceOf(address(this));
    }

    /**
     * @notice Get borrower of a credit note
     * @param tokenId Token ID
     * @return Borrower address
     */
    function getNoteBorrower(uint256 tokenId) external view returns (address) {
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();
        return creditNoteData[tokenId].borrower;
    }

    /**
     * @notice Get principal amount of a credit note
     * @param tokenId Token ID
     * @return Principal amount in wstETH
     */
    function getNotePrincipalAmount(uint256 tokenId) external view returns (uint256) {
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();
        return creditNoteData[tokenId].principalAmount;
    }

    /**
     * @notice Get advance amount of a credit note
     * @param tokenId Token ID
     * @return Advance amount in wstETH
     */
    function getNoteAdvanceAmount(uint256 tokenId) external view returns (uint256) {
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();
        return creditNoteData[tokenId].advanceAmount;
    }

    /**
     * @notice Get interest rate of a credit note
     * @param tokenId Token ID
     * @return Interest rate in basis points
     */
    function getNoteInterestRate(uint256 tokenId) external view returns (uint256) {
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();
        return creditNoteData[tokenId].interestRate;
    }

    /**
     * @notice Get maturity timestamp of a credit note
     * @param tokenId Token ID
     * @return Maturity timestamp
     */
    function getNoteMaturity(uint256 tokenId) external view returns (uint256) {
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();
        return creditNoteData[tokenId].maturity;
    }

    /**
     * @notice Get creation timestamp of a credit note
     * @param tokenId Token ID
     * @return Creation timestamp
     */
    function getNoteCreatedAt(uint256 tokenId) external view returns (uint256) {
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();
        return creditNoteData[tokenId].createdAt;
    }

    /**
     * @notice Get total paid amount of a credit note
     * @param tokenId Token ID
     * @return Total paid amount
     */
    function getNoteTotalPaid(uint256 tokenId) external view returns (uint256) {
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();
        return creditNoteData[tokenId].totalPaid;
    }

    /**
     * @notice Get status of a credit note
     * @param tokenId Token ID
     * @return Note status
     */
    function getNoteStatus(uint256 tokenId) external view returns (NoteStatus) {
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();
        return creditNoteData[tokenId].status;
    }

    /**
     * @notice Check if a credit note is mature
     * @param tokenId Token ID
     * @return True if mature
     */
    function isNoteMature(uint256 tokenId) external view returns (bool) {
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();
        return block.timestamp >= creditNoteData[tokenId].maturity;
    }

    /**
     * @notice Get remaining debt of a credit note
     * @param tokenId Token ID
     * @return Remaining debt amount
     */
    function getNoteRemainingDebt(uint256 tokenId) external view returns (uint256) {
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();
        CreditNoteData memory data = creditNoteData[tokenId];
        if (data.principalAmount <= data.totalPaid) {
            return 0;
        }
        return data.principalAmount - data.totalPaid;
    }

    /**
     * @notice Override supportsInterface to handle multiple inheritance
     * @param interfaceId Interface ID to check
     * @return True if interface is supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Override tokenURI to use our custom implementation
     * @param tokenId Token ID
     * @return Token URI string
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        if (ownerOf(tokenId) == address(0)) revert TokenNotFound();
        return _buildTokenURI(tokenId);
    }

    /**
     * @notice Build token URI from stored credit note data
     * @param tokenId Token ID
     * @return Base64-encoded JSON metadata
     */
    function _buildTokenURI(uint256 tokenId) internal view returns (string memory) {
        CreditNoteData memory data = creditNoteData[tokenId];

        string memory statusString;
        if (data.status == NoteStatus.Active) {
            statusString = "Active";
        } else if (data.status == NoteStatus.Repaid) {
            statusString = "Repaid";
        } else {
            statusString = "Defaulted";
        }

        string memory json = string(
            abi.encodePacked(
                '{"name": "Credora Credit Note #',
                tokenId.toString(),
                '", "description": "A credit note representing a secured loan backed by CRD tokens", ',
                '"image": "https://credora.com/nft/', tokenId.toString(), '.png", ',
                '"attributes": [',
                '{"trait_type": "Borrower", "value": "',
                Strings.toHexString(uint256(uint160(data.borrower)), 20),
                '"}, ',
                '{"trait_type": "Principal Amount", "value": ',
                data.principalAmount.toString(),
                '}, ',
                '{"trait_type": "Advance Amount", "value": ',
                data.advanceAmount.toString(),
                '}, ',
                '{"trait_type": "Interest Rate", "value": ',
                data.interestRate.toString(),
                ', "display_type": "boost_percentage"}, ',
                '{"trait_type": "Maturity", "value": ',
                data.maturity.toString(),
                ', "display_type": "date"}, ',
                '{"trait_type": "Created At", "value": ',
                data.createdAt.toString(),
                ', "display_type": "date"}, ',
                '{"trait_type": "Total Paid", "value": ',
                data.totalPaid.toString(),
                '}, ',
                '{"trait_type": "Status", "value": "',
                statusString,
                '"}, ',
                '{"trait_type": "CRD Balance", "value": ',
                balanceOfToken[tokenId].toString(),
                '}]}'
            )
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(bytes(json))
            )
        );
    }
}
