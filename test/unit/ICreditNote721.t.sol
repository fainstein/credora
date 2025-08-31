// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CreditNote721} from "../../src/contracts/CreditNote721.sol";
import {ICreditNote721} from "../../src/interfaces/ICreditNote721.sol";

// Simple Mock CRD Token
contract MockCRDToken {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}

// Simple Mock CRD Vault
contract MockCRDVault {
    function returnCRDFromNote(address from, uint256 noteId, uint256 amount) external {
        // Mock implementation - just accept the call
    }
}

/**
 * @title CreditNote721 Unit Tests
 * @author Credora Protocol
 * @notice Tests for ERC-721 credit notes with internal CRD escrow
 */
contract CreditNote721Test is Test {
    CreditNote721 public note;
    MockCRDToken public crdToken;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    uint256 public constant INITIAL_BALANCE = 1000 ether;

    function setUp() public {
        // Deploy mock CRD token
        crdToken = new MockCRDToken();

        // Deploy mock CRD Vault (for testing)
        MockCRDVault mockVault = new MockCRDVault();

        // Deploy CreditNote721
        vm.prank(owner);
        note = new CreditNote721(IERC20(address(crdToken)), address(mockVault), owner);

        // Fund test accounts
        crdToken.mint(alice, INITIAL_BALANCE);
        crdToken.mint(bob, INITIAL_BALANCE);
        crdToken.mint(carol, INITIAL_BALANCE);
    }

    // mintWithDeposit tests
    function test_mintWithDeposit_should_mint_token_and_deposit_crd() public {
        uint256 depositAmount = 100 ether;

        // Pre-fund the contract with CRD tokens (as would happen from vault)
        crdToken.mint(address(note), depositAmount);

        // Mint token - CRD tokens are already in contract
        vm.startPrank(alice);
        uint256 tokenId = note.mintWithDeposit(
            alice,
            depositAmount,
            alice, // borrower
            1 ether, // principalAmount
            0.1 ether, // advanceAmount
            500, // interestRate (5%)
            block.timestamp + 365 days // maturity
        );
        vm.stopPrank();

        // Verify NFT ownership
        assertEq(note.ownerOf(tokenId), alice, "Alice should own the token");

        // Verify CRD balance
        assertEq(note.balanceOfStable(tokenId), depositAmount, "Token should have CRD balance");

        // Verify CRD tokens remain in contract
        assertEq(crdToken.balanceOf(address(note)), depositAmount, "Contract should hold CRD tokens");
    }

    function test_mintWithDeposit_should_emit_events() public {
        uint256 depositAmount = 50 ether;

        // Pre-fund the contract with CRD tokens
        crdToken.mint(address(note), depositAmount);

        vm.startPrank(alice);

        vm.expectEmit(true, true, false, true);
        emit ICreditNote721.Minted(1, alice, depositAmount);

        note.mintWithDeposit(alice, depositAmount, alice, 1 ether, 0.1 ether, 500, block.timestamp + 365 days);
        vm.stopPrank();
    }

    function test_mintWithDeposit_should_revert_on_zero_address() public {
        vm.startPrank(alice);

        vm.expectRevert(ICreditNote721.ZeroAddress.selector);
        note.mintWithDeposit(address(0), 100 ether, alice, 1 ether, 0.1 ether, 500, block.timestamp + 365 days);
        vm.stopPrank();
    }

    function test_mintWithDeposit_should_revert_on_zero_amount() public {
        vm.startPrank(alice);

        vm.expectRevert(ICreditNote721.ZeroAmount.selector);
        note.mintWithDeposit(alice, 0, alice, 1 ether, 0.1 ether, 500, block.timestamp + 365 days);
        vm.stopPrank();
    }

    // deposit tests
    function test_deposit_should_increase_token_balance() public {
        // First mint a token
        vm.startPrank(alice);
        crdToken.approve(address(note), 100 ether);
        uint256 tokenId = note.mintWithDeposit(alice, 100 ether, alice, 1 ether, 0.1 ether, 500, block.timestamp + 365 days);
        vm.stopPrank();

        // Deposit more
        uint256 additionalDeposit = 50 ether;
        vm.startPrank(bob);
        crdToken.approve(address(note), additionalDeposit);

        vm.expectEmit(true, false, false, true);
        emit ICreditNote721.Deposited(tokenId, bob, additionalDeposit);

        note.deposit(tokenId, additionalDeposit);
        vm.stopPrank();

        // Verify balance increased
        assertEq(note.balanceOfStable(tokenId), 100 ether + additionalDeposit, "Balance should increase");
    }

    // redeem tests
    function test_redeem_should_revert_not_implemented() public {
        // Pre-fund the contract with CRD tokens
        crdToken.mint(address(note), 100 ether);

        // Mint token for Alice
        vm.startPrank(alice);
        uint256 tokenId = note.mintWithDeposit(alice, 100 ether, alice, 1 ether, 0.1 ether, 500, block.timestamp + 365 days);
        vm.stopPrank();

        // Try to redeem - should revert with not implemented message
        vm.startPrank(alice);
        vm.expectRevert("Redeem not implemented in this version");
        note.redeem(tokenId);
        vm.stopPrank();

        // Verify token still exists and is owned by Alice
        assertEq(note.ownerOf(tokenId), alice, "Token should still exist");
        assertEq(note.balanceOfStable(tokenId), 100 ether, "Token balance should be unchanged");
    }

    function test_redeem_should_revert_not_implemented_for_non_owner() public {
        // Pre-fund the contract with CRD tokens
        crdToken.mint(address(note), 100 ether);

        // Mint token for Alice
        vm.startPrank(alice);
        uint256 tokenId = note.mintWithDeposit(alice, 100 ether, alice, 1 ether, 0.1 ether, 500, block.timestamp + 365 days);
        vm.stopPrank();

        // Bob tries to redeem - should still revert with not implemented
        vm.startPrank(bob);
        vm.expectRevert("Redeem not implemented in this version");
        note.redeem(tokenId);
        vm.stopPrank();
    }

    function test_redeem_should_revert_not_implemented_for_non_existent() public {
        vm.startPrank(alice);
        vm.expectRevert("Redeem not implemented in this version");
        note.redeem(999); // Non-existent token
        vm.stopPrank();
    }

    // ERC721 standard tests
    function test_safeTransferFrom_should_transfer_ownership() public {
        // Mint token for Alice
        vm.startPrank(alice);
        crdToken.approve(address(note), 100 ether);
        uint256 tokenId = note.mintWithDeposit(alice, 100 ether, alice, 1 ether, 0.1 ether, 500, block.timestamp + 365 days);
        vm.stopPrank();

        // Alice transfers to Bob
        vm.startPrank(alice);
        note.safeTransferFrom(alice, bob, tokenId);
        vm.stopPrank();

        // Verify ownership
        assertEq(note.ownerOf(tokenId), bob, "Bob should own the token");

        // CRD balance should remain the same
        assertEq(note.balanceOfStable(tokenId), 100 ether, "CRD balance should be preserved");
    }

    // View functions tests
    function test_balanceOfStable_should_return_correct_balance() public {
        vm.startPrank(alice);
        crdToken.approve(address(note), 100 ether);
        uint256 tokenId = note.mintWithDeposit(alice, 100 ether, alice, 1 ether, 0.1 ether, 500, block.timestamp + 365 days);
        vm.stopPrank();

        assertEq(note.balanceOfStable(tokenId), 100 ether, "Should return correct balance");
    }

    function test_nextId_should_increment() public {
        assertEq(note.nextId(), 1, "Initial nextId should be 1");

        vm.startPrank(alice);
        crdToken.approve(address(note), 100 ether);
        note.mintWithDeposit(alice, 100 ether, alice, 1 ether, 0.1 ether, 500, block.timestamp + 365 days);
        vm.stopPrank();

        assertEq(note.nextId(), 2, "NextId should increment after mint");
    }
}
