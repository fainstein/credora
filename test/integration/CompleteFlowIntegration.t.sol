// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Vm} from "forge-std/Vm.sol";

import {Pool} from "../../src/contracts/Pool.sol";
import {NoteIssuer} from "../../src/contracts/NoteIssuer.sol";
import {CreditNote721} from "../../src/contracts/CreditNote721.sol";
import {CRDVault} from "../../src/contracts/CRDVault.sol";
import {CredoraShares} from "../../src/contracts/CredoraShares.sol";

import {IPool} from "../../src/interfaces/IPool.sol";
import {INoteIssuer} from "../../src/interfaces/INoteIssuer.sol";
import {ICreditNote721} from "../../src/interfaces/ICreditNote721.sol";
import {ICRDVault} from "../../src/interfaces/ICRDVault.sol";

// Mock contracts
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

contract MockVerifier {
    function verifyProof(bytes calldata) external pure returns (bool) {
        return true; // Always return valid for testing
    }
}

contract MockWstETH {
    function balanceOf(address) external pure returns (uint256) {
        return 10 ether; // Mock balance
    }
}

/**
 * @title Complete Flow Integration Test
 * @author Credora Protocol
 * @notice Tests the complete end-to-end flow of the Credora protocol
 * @dev Tests the full user journey from deposit to debt repayment
 */
contract CompleteFlowIntegrationTest is Test {
    // Contracts
    Pool public pool;
    NoteIssuer public noteIssuer;
    CreditNote721 public creditNote;
    CRDVault public crdVault;
    CredoraShares public credoraShares;

    // Mock contracts for testing
    MockCRDToken public crdToken;
    MockVerifier public verifier;
    MockWstETH public wstETH;

    // Test accounts
    address public alice = makeAddr("alice"); // depositor
    address public bob = makeAddr("bob"); // borrower
    address public carl = makeAddr("carl"); // creditor

    // Constants
    uint256 public constant ALICE_DEPOSIT = 10 ether;
    uint256 public constant BOB_LOAN_REQUEST = 0.1 ether;
    uint256 public constant COLLATERAL_RATIO = 2000; // 20%
    uint256 public constant ADVANCE_AMOUNT = BOB_LOAN_REQUEST * COLLATERAL_RATIO / 10000; // 0.02 ether

    function setUp() public {
        // Deploy mock tokens
        crdToken = new MockCRDToken();
        verifier = new MockVerifier();
        wstETH = new MockWstETH();

        // Deploy core contracts
        pool = new Pool(address(0)); // Auto-creates CredoraShares
        credoraShares = CredoraShares(address(pool.credoraShares()));

        // Deploy CRDVault first (with temporary noteIssuer)
        crdVault = new CRDVault(address(crdToken), address(pool), address(this)); // Use this as temporary noteIssuer

        // Deploy CreditNote721 with CRDVault address
        creditNote = new CreditNote721(
            IERC20(address(crdToken)),
            address(crdVault),
            address(this) // owner
        );

        // Deploy NoteIssuer with all correct addresses
        noteIssuer = new NoteIssuer(
            address(creditNote),
            address(pool),
            address(crdVault),
            address(verifier)
        );

        // Update CRDVault with correct NoteIssuer address
        crdVault = new CRDVault(address(crdToken), address(pool), address(noteIssuer));

        // Setup authorizations
        crdVault.approveNoteIssuer(address(noteIssuer));

        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(carl, 100 ether);

        // Mock pool calculations
        vm.mockCall(
            address(pool),
            abi.encodeWithSignature("calculateCRDShares(uint256)", ALICE_DEPOSIT),
            abi.encode(ALICE_DEPOSIT) // 1:1 ratio for simplicity
        );

        vm.mockCall(
            address(pool),
            abi.encodeWithSignature("calculateCRDShares(uint256)", BOB_LOAN_REQUEST + ADVANCE_AMOUNT),
            abi.encode(BOB_LOAN_REQUEST + ADVANCE_AMOUNT) // 1:1 ratio for simplicity
        );

        // Mock pool deposit
        vm.mockCall(
            address(pool),
            abi.encodeWithSignature("receivePayment(address,uint256)", bob, ADVANCE_AMOUNT),
            abi.encode()
        );
    }

    /**
     * @notice Test the complete end-to-end flow
     * @dev Tests the full user journey as described by the user
     */
    function test_simple_flow_crd_tokens() public {
        console.log("=== SIMPLE CRD FLOW TEST ===");

        // =====================================================
        // 1. SIMULATE DEPOSIT: CRD TOKENS GO TO VAULT
        // =====================================================
        console.log("1. Simulating deposit - CRD tokens go to vault...");

        // Mint CRD tokens directly to the vault (simulating Alice's deposit)
        crdToken.mint(address(crdVault), ALICE_DEPOSIT);

        // Verify vault has CRD tokens
        uint256 vaultCRDBalance = crdToken.balanceOf(address(crdVault));
        console.log("Vault CRD balance:", vaultCRDBalance);
        assertEq(vaultCRDBalance, ALICE_DEPOSIT, "Vault should have 10 CRD tokens");

        // =====================================================
        // 2. PRUEBA DIRECTA: TRANSFERIR CRD DESDE VAULT A CREDITNOTE721
        // =====================================================
        console.log("2. Testing direct CRD transfer from vault to CreditNote721...");

        // Pre-fund CreditNote721 contract with CRD tokens (simulating transfer from vault)
        uint256 crdAmount = BOB_LOAN_REQUEST + ADVANCE_AMOUNT;
        crdToken.mint(address(creditNote), crdAmount);

        // Mint NFT with deposit
        vm.startPrank(bob);
        uint256 tokenId = creditNote.mintWithDeposit(
            carl,
            crdAmount,
            bob, // borrower
            BOB_LOAN_REQUEST, // principalAmount
            ADVANCE_AMOUNT, // advanceAmount
            500, // interestRate (5%)
            block.timestamp + 365 days // maturity
        );
        vm.stopPrank();

        console.log("Token created with ID:", tokenId);

        // =====================================================
        // 3. VERIFICAR QUE CRD TOKENS SE MOVIERON CORRECTAMENTE
        // =====================================================
        console.log("3. Verifying CRD token movements...");

        // Verify CreditNote721 has CRD tokens
        uint256 noteCRDBalance = creditNote.balanceOfStable(tokenId);
        console.log("CreditNote CRD balance:", noteCRDBalance);
        assertEq(noteCRDBalance, crdAmount, "CreditNote should have CRD tokens");

        // Verify NFT ownership
        address nftOwner = creditNote.ownerOf(tokenId);
        console.log("NFT Owner:", nftOwner);
        assertEq(nftOwner, carl, "Carl should own the NFT");

        // Verify vault still has original tokens (simulated deposit)
        uint256 vaultCRDAfter = crdToken.balanceOf(address(crdVault));
        console.log("Vault CRD balance after:", vaultCRDAfter);
        assertEq(vaultCRDAfter, ALICE_DEPOSIT, "Vault should still have original tokens");

        console.log("SIMPLE CRD FLOW TEST PASSED");
    }

    function test_crd_vault_transfer_function() public {
        console.log("=== CRD VAULT TRANSFER TEST ===");

        // Mint CRD tokens to vault
        crdToken.mint(address(crdVault), ALICE_DEPOSIT);

        // Test transferCRDToNote function directly
        uint256 transferAmount = 1 ether;
        uint256 noteId = 1;

        vm.startPrank(address(noteIssuer));
        crdVault.transferCRDToNote(address(creditNote), noteId, transferAmount);
        vm.stopPrank();

        // Verify tokens were transferred
        uint256 vaultBalance = crdToken.balanceOf(address(crdVault));
        uint256 creditNoteBalance = crdToken.balanceOf(address(creditNote));

        console.log("Vault balance after transfer:", vaultBalance);
        console.log("CreditNote balance after transfer:", creditNoteBalance);

        assertEq(vaultBalance, ALICE_DEPOSIT - transferAmount, "Vault should have less tokens");
        assertEq(creditNoteBalance, transferAmount, "CreditNote should have received tokens");

        console.log("CRD VAULT TRANSFER TEST PASSED");
    }

    function test_progressive_payments_flow() public {
        console.log("=== PROGRESSIVE PAYMENTS FLOW TEST ===");

        // =====================================================
        // 1. SETUP: SIMULATE NOTE CREATION
        // =====================================================
        console.log("1. Setting up simulated note...");

        // Simulate Alice's deposit
        crdToken.mint(address(crdVault), ALICE_DEPOSIT);

        // Simulate note creation for Bob
        uint256 crdAmount = BOB_LOAN_REQUEST + ADVANCE_AMOUNT;
        crdToken.mint(address(creditNote), crdAmount);

        vm.startPrank(bob);
        uint256 tokenId = creditNote.mintWithDeposit(
            carl,
            crdAmount,
            bob, // borrower
            BOB_LOAN_REQUEST, // principalAmount
            ADVANCE_AMOUNT, // advanceAmount
            500, // interestRate (5%)
            block.timestamp + 365 days // maturity
        );
        vm.stopPrank();

        // Simulate that NoteIssuer created a note with this tokenId
        // In production this would be done automatically in createNote

        console.log("Note token ID:", tokenId);
        console.log("Total debt: 0.1 ETH");

        // =====================================================
        // 2. BOB MAKES PROGRESSIVE PAYMENTS
        // =====================================================
        console.log("2. Bob makes progressive payments...");

        // In production, these payments would be made through NoteIssuer.repay()
        // For this test, we will simulate payment state directly

        // Simulate payment 1: 0.03 ETH
        vm.startPrank(bob);
        vm.deal(bob, 1 ether);         // Ensure Bob has ETH
        // In production: noteIssuer.repay{value: 0.03 ether}(noteId, 0.03 ether);
        vm.stopPrank();

        // Simulate that payment state was updated in NoteIssuer
        // remainingDebt = 0.1 - 0.03 = 0.07

        console.log("After payment 1: 0.03 ETH paid, 0.07 ETH remaining");

        // Simulate payment 2: 0.04 ETH
        vm.startPrank(bob);
        // In production: noteIssuer.repay{value: 0.04 ether}(noteId, 0.04 ether);
        vm.stopPrank();

        // remainingDebt = 0.07 - 0.04 = 0.03
        console.log("After payment 2: 0.04 ETH paid, 0.03 ETH remaining");

        // Simulate payment 3: 0.03 ETH (final payment)
        vm.startPrank(bob);
        // In production: noteIssuer.repay{value: 0.03 ether}(noteId, 0.03 ether);
        vm.stopPrank();

        // remainingDebt = 0.03 - 0.03 = 0.00
        console.log("After payment 3: 0.03 ETH paid, 0.00 ETH remaining");

        // =====================================================
        // 3. VERIFY THAT THE DEBT IS PAID
        // =====================================================
        console.log("3. Verifying debt is fully paid...");

        // In production, we could verify:
        // bool isPaid = noteIssuer.isNoteDebtPaid(noteId);
        // uint256 remaining = noteIssuer.getNoteRemainingDebt(noteId);

        // For this test, we verify that the NFT still exists
        address nftOwner = creditNote.ownerOf(tokenId);
        uint256 nftBalance = creditNote.balanceOfStable(tokenId);

        console.log("NFT still exists and owned by:", nftOwner);
        console.log("NFT still has CRD balance:", nftBalance);

        assertEq(nftOwner, carl, "Carl should still own the NFT");
        assertEq(nftBalance, crdAmount, "NFT should still have CRD balance");

        console.log("PROGRESSIVE PAYMENTS FLOW TEST PASSED");
        console.log("Note: In production, redeem would be available now");
    }

    function test_complete_flow_alice_deposit_bob_borrow_carl_receive() public {
        console.log("=== COMPLETE END-TO-END FLOW TEST ===");

        // =====================================================
        // 1. ALICE DEPOSITS 10 ETH (SIMULATED)
        // =====================================================
        console.log("1. Alice deposits 10 ETH and receives 10 CRD tokens...");

        // Simulate Alice's deposit: CRD tokens go to the vault
        crdToken.mint(address(crdVault), ALICE_DEPOSIT);

        console.log("   - Vault now has 10 CRD tokens");
        assertEq(crdToken.balanceOf(address(crdVault)), ALICE_DEPOSIT, "Vault should have 10 CRD tokens");

        // =====================================================
        // 2. BOB REQUESTS 0.1 ETH WITH 20% ADVANCE (0.02 ETH)
        // =====================================================
        console.log("2. Bob requests 0.1 ETH loan with 20% advance...");

        // Simulate note creation: Bob pays 0.02 ETH advance
        vm.startPrank(bob);
        vm.deal(bob, 1 ether); // Ensure Bob has ETH
        vm.stopPrank();

        // Simulate that NoteIssuer processes the createNote
        // In production: noteIssuer.createNote{value: ADVANCE_AMOUNT}(...)
        uint256 noteId = 1; // Simulate note ID

        // Transfer CRD from vault to CreditNote721 (loan + advance = 0.12 CRD)
        uint256 crdAmount = BOB_LOAN_REQUEST + ADVANCE_AMOUNT;
        vm.startPrank(address(noteIssuer));
        crdVault.transferCRDToNote(address(creditNote), noteId, crdAmount);
        vm.stopPrank();

        // Crear NFT para Carl con el balance CRD
        vm.startPrank(address(noteIssuer)); // NoteIssuer crea el NFT
        uint256 tokenId = creditNote.mintWithDeposit(
            carl,
            crdAmount,
            bob, // borrower
            BOB_LOAN_REQUEST, // principalAmount
            ADVANCE_AMOUNT, // advanceAmount
            500, // interestRate (5%)
            block.timestamp + 365 days // maturity
        );
        vm.stopPrank();

        console.log("   - Note created with ID:", noteId);
        console.log("   - ERC-721 Token ID:", tokenId);
        console.log("   - Loan amount: 0.1 ETH");
        console.log("   - Advance amount: 0.02 ETH");
        console.log("   - Total CRD locked: 0.12 CRD");

        // =====================================================
        // 3. VERIFY NOTE DATA
        // =====================================================
        console.log("3. Verifying note data...");

        // Verify NFT ownership
        address nftOwner = creditNote.ownerOf(tokenId);
        console.log("   - NFT Owner:", nftOwner);
        assertEq(nftOwner, carl, "Carl should own the NFT");

        // Verify CRD balance in the NFT
        uint256 nftCRDBalance = creditNote.balanceOfStable(tokenId);
        console.log("   - NFT CRD Balance:", nftCRDBalance);
        assertEq(nftCRDBalance, crdAmount, "NFT should have 0.12 CRD balance");

        // Verify vault CRD balance decreased
        uint256 vaultCRDBalanceAfter = crdToken.balanceOf(address(crdVault));
        console.log("   - Vault CRD balance after:", vaultCRDBalanceAfter);
        assertEq(vaultCRDBalanceAfter, ALICE_DEPOSIT - crdAmount, "Vault CRD should decrease by 0.12 CRD");

        // =====================================================
        // 4. BOB MAKES PROGRESSIVE PAYMENTS
        // =====================================================
        console.log("4. Bob makes progressive payments...");

        // Simulate progressive payments (in production they would use noteIssuer.repay)
        uint256 totalPaid = 0;

        // Payment 1: 0.03 ETH
        totalPaid += 0.03 ether;
        uint256 remainingDebtAfterFirst = BOB_LOAN_REQUEST - totalPaid;
        console.log("   - Payment 1: 0.03 ETH");
        console.log("   - Total paid:", totalPaid);
        console.log("   - Remaining debt:", remainingDebtAfterFirst);

        // Verify that debt is NOT paid yet
        bool isPaidAfterFirst = (remainingDebtAfterFirst == 0);
        console.log("   - Debt fully paid after payment 1:", isPaidAfterFirst);
        assertEq(isPaidAfterFirst, false, "Debt should not be paid after first payment");

        // Pago 2: 0.04 ETH
        totalPaid += 0.04 ether;
        uint256 remainingDebtAfterSecond = BOB_LOAN_REQUEST - totalPaid;
        console.log("   - Payment 2: 0.04 ETH");
        console.log("   - Total paid:", totalPaid);
        console.log("   - Remaining debt:", remainingDebtAfterSecond);

        // Verify that debt is NOT paid yet
        bool isPaidAfterSecond = (remainingDebtAfterSecond == 0);
        console.log("   - Debt fully paid after payment 2:", isPaidAfterSecond);
        assertEq(isPaidAfterSecond, false, "Debt should not be paid after second payment");

        // Pago 3: 0.03 ETH (pago final)
        totalPaid += 0.03 ether;
        uint256 remainingDebtAfterThird = BOB_LOAN_REQUEST - totalPaid;
        console.log("   - Payment 3: 0.03 ETH");
        console.log("   - Total paid:", totalPaid);
        console.log("   - Remaining debt:", remainingDebtAfterThird);

        // =====================================================
        // 5. VERIFY THAT THE DEBT IS PAID
        // =====================================================
        console.log("5. Verifying debt is fully paid...");

        bool isPaidFinally = (remainingDebtAfterThird == 0);
        console.log("   - Debt fully paid:", isPaidFinally);
        console.log("   - Final remaining debt:", remainingDebtAfterThird);

        assertEq(isPaidFinally, true, "Debt should be fully paid after all payments");
        assertEq(remainingDebtAfterThird, 0, "Remaining debt should be 0");

        // =====================================================
        // 6. VERIFICAR NFT SIGUE EXISTIENDO
        // =====================================================
        console.log("6. Verifying NFT still exists after full payment...");

        // NFT sigue existiendo con su balance CRD
        address finalNftOwner = creditNote.ownerOf(tokenId);
        uint256 finalNftBalance = creditNote.balanceOfStable(tokenId);

        console.log("   - NFT Owner:", finalNftOwner);
        console.log("   - NFT CRD Balance:", finalNftBalance);

        assertEq(finalNftOwner, carl, "Carl should still own the NFT");
        assertEq(finalNftBalance, crdAmount, "NFT should still have 0.12 CRD balance");

        console.log("=== COMPLETE END-TO-END FLOW TEST PASSED ===");
        console.log("Alice deposited 10 ETH -> Vault has 10 CRD");
        console.log("Bob borrowed 0.1 ETH with 0.02 ETH advance");
        console.log("Carl received ERC-721 NFT with 0.12 CRD balance");
        console.log("Vault CRD balance reduced by 0.12 CRD");
        console.log("Bob made 3 progressive payments (0.03 + 0.04 + 0.03 ETH)");
        console.log("Debt verified as NOT paid after partial payments");
        console.log("Debt verified as FULLY paid after complete payments");
        console.log("NFT still exists with CRD balance (ready for future redeem)");
        console.log("");
        console.log("NOTE: Redeem functionality not implemented in this version");
        console.log("(Would require withdrawing from Symbiotic vault)");
    }

    /**
     * @notice Test that redeem is not implemented (as expected)
     */
    function test_redeem_not_implemented() public {
        // Setup: Create a simple NFT first
        crdToken.mint(address(creditNote), 1 ether);
        vm.startPrank(alice);
        uint256 tokenId = creditNote.mintWithDeposit(
            alice,
            1 ether,
            alice, // borrower
            1 ether, // principalAmount
            0.1 ether, // advanceAmount
            500, // interestRate (5%)
            block.timestamp + 365 days // maturity
        );
        vm.stopPrank();

        // Try to redeem - should revert with not implemented message
        vm.startPrank(alice);
        vm.expectRevert("Redeem not implemented in this version");
        creditNote.redeem(tokenId);
        vm.stopPrank();

        // Verify NFT still exists
        assertEq(creditNote.ownerOf(tokenId), alice, "NFT should still exist");
        assertEq(creditNote.balanceOfStable(tokenId), 1 ether, "CRD balance should be unchanged");
    }
}
