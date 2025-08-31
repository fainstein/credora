// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICRDVault} from "../interfaces/ICRDVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title CRDVault
 * @dev Vault that holds all minted CRD tokens from pool deposits
 * Manages CRD token supply, handles minting/burning operations,
 * and provides approvals for NoteIssuer to transfer CRD when creating notes.
 */
contract CRDVault is ICRDVault, Ownable {
    using SafeERC20 for IERC20;

    // Immutable contract references
    IERC20 public immutable crdToken;
    address public immutable pool;
    address public immutable noteIssuer;

    // Authorized addresses for minting/burning
    mapping(address => bool) private _authorizedAddresses;

    constructor(
        address _crdToken,
        address _pool,
        address _noteIssuer
    ) Ownable(msg.sender) {
        if (_crdToken == address(0)) revert ZeroAddress();
        if (_pool == address(0)) revert ZeroAddress();
        if (_noteIssuer == address(0)) revert ZeroAddress();

        crdToken = IERC20(_crdToken);
        pool = _pool;
        noteIssuer = _noteIssuer;

        // Set initial authorized addresses
        _authorizedAddresses[_pool] = true;
        _authorizedAddresses[noteIssuer] = true;
        _authorizedAddresses[owner()] = true;
    }

    modifier onlyAuthorized() {
        if (!_authorizedAddresses[msg.sender]) revert UnauthorizedAccess();
        _;
    }

    modifier validAddress(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }

    modifier validAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    /**
     * @notice Mint CRD tokens to a recipient
     */
    function mintCRD(address to, uint256 amount)
        external
        onlyAuthorized
        validAddress(to)
        validAmount(amount)
    {
        // Mint CRD tokens (assuming the CRD token has mint functionality)
        // For now, we'll emit the event - in production this would call the actual mint function
        emit CRDMinted(to, amount);
    }

    /**
     * @notice Burn CRD tokens from a holder
     */
    function burnCRD(address from, uint256 amount)
        external
        onlyAuthorized
        validAddress(from)
        validAmount(amount)
    {
        // Burn CRD tokens (assuming the CRD token has burn functionality)
        // For now, we'll emit the event - in production this would call the actual burn function
        emit CRDBurned(from, amount);
    }

    /**
     * @notice Transfer CRD to NoteIssuer for note creation
     */
    function transferCRDToNote(
        address noteIssuerAddr,
        uint256 noteId,
        uint256 amount
    )
        external
        validAddress(noteIssuerAddr)
        validAmount(amount)
    {
        // Only NoteIssuer can call this function
        if (msg.sender != noteIssuer) revert UnauthorizedAccess();

        // Transfer CRD from vault to NoteIssuer
        // In production, this would transfer actual CRD tokens
        emit CRDTransferredToNote(noteIssuerAddr, noteId, amount);
    }

    /**
     * @notice Return CRD from redeemed note to vault
     */
    function returnCRDFromNote(
        address from,
        uint256 noteId,
        uint256 amount
    )
        external
        validAddress(from)
        validAmount(amount)
    {
        // Accept CRD return from anyone (flexible for different redemption scenarios)
        // In production, this would transfer actual CRD tokens to the vault
        emit CRDReturnedFromNote(from, noteId, amount);
    }

    /**
     * @notice Set approval for NoteIssuer to transfer CRD
     */
    function approveNoteIssuer(address noteIssuerAddr)
        external
        onlyOwner
        validAddress(noteIssuerAddr)
    {
        // Approve NoteIssuer to transfer CRD tokens
        // In production, this would call approve on the actual CRD token
        emit NoteIssuerApproved(noteIssuerAddr, type(uint256).max);
    }

    /**
     * @notice Get total CRD supply
     */
    function totalSupply() external view returns (uint256 supply) {
        return crdToken.totalSupply();
    }

    /**
     * @notice Get CRD balance of an account
     */
    function balanceOf(address account) external view returns (uint256 balance) {
        return crdToken.balanceOf(account);
    }

    /**
     * @notice Get the CRD token contract address
     */
    function getCRDToken() external view returns (IERC20) {
        return crdToken;
    }

    /**
     * @notice Check if address is authorized to mint/burn CRD
     */
    function isAuthorized(address account) external view returns (bool authorized) {
        return _authorizedAddresses[account];
    }

    /**
     * @dev Internal function to add authorized address
     */
    function _addAuthorizedAddress(address account) internal {
        _authorizedAddresses[account] = true;
    }

    /**
     * @dev Internal function to remove authorized address
     */
    function _removeAuthorizedAddress(address account) internal {
        _authorizedAddresses[account] = false;
    }
}
