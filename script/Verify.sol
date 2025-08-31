// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CredoraShares} from "../src/contracts/CredoraShares.sol";
import {Pool} from "../src/contracts/Pool.sol";
import {Groth16Verifier} from "../src/contracts/generated/verifier.sol";
import {Groth16VerifierWrapper} from "../src/contracts/Groth16VerifierWrapper.sol";
import {CreditNote721} from "../src/contracts/CreditNote721.sol";
import {CRDVault} from "../src/contracts/CRDVault.sol";
import {NoteIssuer} from "../src/contracts/NoteIssuer.sol";

/**
 * @title Credora Protocol Post-Deployment Verification
 * @notice Verifies that deployed contracts are functioning correctly
 */
contract Verify is Script {
    // Contract addresses (these should be set from deployment output)
    address public credoraSharesAddr;
    address public poolAddr;
    address public groth16VerifierAddr;
    address public verifierWrapperAddr;
    address public creditNote721Addr;
    address public crdVaultAddr;
    address public noteIssuerAddr;

    // Contract instances
    CredoraShares public credoraShares;
    Pool public pool;
    Groth16Verifier public groth16Verifier;
    Groth16VerifierWrapper public verifierWrapper;
    CreditNote721 public creditNote721;
    CRDVault public crdVault;
    NoteIssuer public noteIssuer;

    function setUp() public {
        // Load addresses from environment variables or deployment file
        // In production, these would be loaded from a deployment artifact file
        loadContractAddresses();
        initializeContracts();
    }

    function run() public view {
        console.log("Starting Credora Protocol verification...");

        // Verify contract deployments
        verifyContractDeployments();

        // Verify contract relationships
        verifyContractRelationships();

        // Verify basic functionality
        verifyBasicFunctionality();

        // Verify protocol constants
        verifyProtocolConstants();

        console.log("Credora Protocol verification completed successfully!");
    }

    /**
     * @notice Load contract addresses from environment or deployment file
     */
    function loadContractAddresses() internal {
        // In a real deployment, these would be loaded from:
        // 1. Environment variables
        // 2. Deployment artifact JSON files
        // 3. Chain-specific configuration

        // For now, these are placeholders - in practice you'd load from vm.envAddress()
        credoraSharesAddr = address(0); // vm.envAddress("CREDORA_SHARES_ADDRESS")
        poolAddr = address(0); // vm.envAddress("POOL_ADDRESS")
        groth16VerifierAddr = address(0); // vm.envAddress("VERIFIER_ADDRESS")
        verifierWrapperAddr = address(0); // vm.envAddress("VERIFIER_WRAPPER_ADDRESS")
        creditNote721Addr = address(0); // vm.envAddress("CREDIT_NOTE_ADDRESS")
        crdVaultAddr = address(0); // vm.envAddress("CRD_VAULT_ADDRESS")
        noteIssuerAddr = address(0); // vm.envAddress("NOTE_ISSUER_ADDRESS")

        console.log("Loaded contract addresses:");
        console.log("CredoraShares:", credoraSharesAddr);
        console.log("Pool:", poolAddr);
        console.log("Groth16Verifier:", groth16VerifierAddr);
        console.log("VerifierWrapper:", verifierWrapperAddr);
        console.log("CreditNote721:", creditNote721Addr);
        console.log("CRDVault:", crdVaultAddr);
        console.log("NoteIssuer:", noteIssuerAddr);
    }

    /**
     * @notice Initialize contract instances
     */
    function initializeContracts() internal {
        if (credoraSharesAddr != address(0)) {
            credoraShares = CredoraShares(credoraSharesAddr);
        }
        if (poolAddr != address(0)) {
            pool = Pool(payable(poolAddr));
        }
        if (groth16VerifierAddr != address(0)) {
            groth16Verifier = Groth16Verifier(groth16VerifierAddr);
        }
        if (verifierWrapperAddr != address(0)) {
            verifierWrapper = Groth16VerifierWrapper(verifierWrapperAddr);
        }
        if (creditNote721Addr != address(0)) {
            creditNote721 = CreditNote721(creditNote721Addr);
        }
        if (crdVaultAddr != address(0)) {
            crdVault = CRDVault(crdVaultAddr);
        }
        if (noteIssuerAddr != address(0)) {
            noteIssuer = NoteIssuer(noteIssuerAddr);
        }
    }

    /**
     * @notice Verify that all contracts are deployed
     */
    function verifyContractDeployments() internal view {
        console.log("Verifying contract deployments...");

        require(credoraSharesAddr != address(0), "CredoraShares not deployed");
        require(poolAddr != address(0), "Pool not deployed");
        require(groth16VerifierAddr != address(0), "Groth16Verifier not deployed");
        require(verifierWrapperAddr != address(0), "VerifierWrapper not deployed");
        require(creditNote721Addr != address(0), "CreditNote721 not deployed");
        require(crdVaultAddr != address(0), "CRDVault not deployed");
        require(noteIssuerAddr != address(0), "NoteIssuer not deployed");

        console.log("All contracts are deployed");
    }

    /**
     * @notice Verify relationships between contracts
     */
    function verifyContractRelationships() internal view {
        console.log("Verifying contract relationships...");

        // Verify Pool -> CredoraShares relationship
        require(address(pool.credoraShares()) == credoraSharesAddr, "Pool CredoraShares reference incorrect");

        // Verify NoteIssuer relationships
        require(address(noteIssuer.note()) == creditNote721Addr, "NoteIssuer CreditNote721 reference incorrect");
        require(address(noteIssuer.pool()) == poolAddr, "NoteIssuer Pool reference incorrect");
        require(address(noteIssuer.crdVault()) == crdVaultAddr, "NoteIssuer CRDVault reference incorrect");
        require(address(noteIssuer.verifier()) == verifierWrapperAddr, "NoteIssuer Verifier reference incorrect");

        // Verify CreditNote721 relationships
        require(address(creditNote721.stable()) == credoraSharesAddr, "CreditNote721 stable reference incorrect");
        require(address(creditNote721.crdVault()) == crdVaultAddr, "CreditNote721 CRDVault reference incorrect");

        // Verify CRDVault relationships
        require(address(crdVault.crdToken()) == credoraSharesAddr, "CRDVault CRD token reference incorrect");
        require(crdVault.pool() == poolAddr, "CRDVault Pool reference incorrect");
        require(crdVault.noteIssuer() == noteIssuerAddr, "CRDVault NoteIssuer reference incorrect");

        // Verify VerifierWrapper relationship
        require(address(verifierWrapper.groth16Verifier()) == groth16VerifierAddr, "VerifierWrapper reference incorrect");

        console.log("All contract relationships verified");
    }

    /**
     * @notice Verify basic contract functionality
     */
    function verifyBasicFunctionality() internal view {
        console.log("Verifying basic functionality...");

        // Verify CredoraShares basic functionality
        require(credoraShares.totalSupply() >= 0, "CredoraShares totalSupply failed");
        require(bytes(credoraShares.name()).length > 0, "CredoraShares name not set");
        require(bytes(credoraShares.symbol()).length > 0, "CredoraShares symbol not set");

        // Verify Pool basic functionality
        require(address(pool.credoraShares()) != address(0), "Pool has no CredoraShares");
        require(pool.getWstETHBalance() >= 0, "Pool wstETH balance check failed");

        // Verify CreditNote721 basic functionality
        require(bytes(creditNote721.name()).length > 0, "CreditNote721 name not set");
        require(bytes(creditNote721.symbol()).length > 0, "CreditNote721 symbol not set");
        require(creditNote721.balanceOf(address(this)) >= 0, "CreditNote721 balance check failed");

        // Verify CRDVault basic functionality
        require(crdVault.totalSupply() >= 0, "CRDVault totalSupply failed");
        require(address(crdVault.crdToken()) != address(0), "CRDVault has no CRD token");

        // Verify NoteIssuer basic functionality
        require(noteIssuer.getMaxLoanAmount() > 0, "NoteIssuer max loan amount not set");
        require(noteIssuer.getAdvanceRatio() > 0, "NoteIssuer advance ratio not set");

        console.log("Basic functionality verified");
    }

    /**
     * @notice Verify protocol constants and configuration
     */
    function verifyProtocolConstants() internal view {
        console.log("Verifying protocol constants...");

        // Verify NoteIssuer constants
        require(noteIssuer.getMaxLoanAmount() == 5 ether, "Max loan amount incorrect");
        require(noteIssuer.getAdvanceRatio() == 2000, "Advance ratio incorrect");

        // Verify network-specific addresses (if on Sepolia)
        if (block.chainid == 11155111) {
            require(pool.getStETHAddress() == 0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af, "stETH address incorrect");
            require(pool.getWstETHAddress() == 0xB82381A3fBD3FaFA77B3a7bE693342618240067b, "wstETH address incorrect");
        }

        console.log("Protocol constants verified");
    }

    /**
     * @notice Test a simple deposit scenario (read-only)
     */
    function testDepositScenario() internal view {
        console.log("Testing deposit scenario...");

        // Calculate shares for 1 ETH deposit
        uint256 depositAmount = 1 ether;
        uint256 expectedShares = pool.calculateCRDShares(depositAmount);

        require(expectedShares > 0, "CRD shares calculation failed");
        require(expectedShares == depositAmount, "CRD shares should equal deposit amount initially");

        console.log("Deposit scenario test passed");
    }

    /**
     * @notice Test credit note creation scenario (read-only)
     */
    function testCreditNoteScenario() internal view {
        console.log("Testing credit note scenario...");

        // Test basic credit note parameters
        uint256 loanAmount = 1 ether;
        uint256 expectedAdvance = noteIssuer.calculateRequiredAdvance(loanAmount);

        require(expectedAdvance > 0, "Advance calculation failed");
        require(expectedAdvance == loanAmount * 2000 / 10000, "Advance amount incorrect");

        console.log("Credit note scenario test passed");
    }
}
