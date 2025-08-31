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
 * @title Credora Protocol Deployment Script
 * @notice Deploys the complete Credora lending protocol
 * @dev Handles circular dependencies by deploying in specific order and updating references
 */
contract Deploy is Script {
    // Contract instances
    CredoraShares public credoraShares;
    Pool public pool;
    Groth16Verifier public groth16Verifier;
    Groth16VerifierWrapper public verifierWrapper;
    CreditNote721 public creditNote721;
    CRDVault public crdVault;
    NoteIssuer public noteIssuer;

    // Deployed contract addresses
    address public credoraSharesAddr;
    address public poolAddr;
    address public groth16VerifierAddr;
    address public verifierWrapperAddr;
    address public creditNote721Addr;
    address public crdVaultAddr;
    address public noteIssuerAddr;

    // Configuration
    address public deployer;
    address public initialOwner;

    function setUp() public {
        deployer = msg.sender;
        initialOwner = deployer; // In production, this would be a multisig or governance contract
    }

    function run() public {
        vm.startBroadcast();

        console.log("Starting Credora Protocol deployment...");

        // Phase 1: Deploy independent contracts
        deployCredoraShares();
        deployPool();
        deployVerifierContracts();

        // Phase 2: Deploy contracts with dependencies (handle circular dependencies)
        deployCreditNote721();
        deployCRDVault();
        deployNoteIssuer();

        // Phase 3: Update contract references to resolve circular dependencies
        updateContractReferences();

        // Phase 4: Verify deployment
        verifyDeployment();

        vm.stopBroadcast();

        console.log("Credora Protocol deployment completed successfully!");
        logDeploymentSummary();
    }

    /**
     * @notice Deploy CredoraShares (CRD token)
     */
    function deployCredoraShares() internal {
        console.log("Deploying CredoraShares...");

        credoraShares = new CredoraShares(initialOwner);
        credoraSharesAddr = address(credoraShares);

        console.log("CredoraShares deployed at:", credoraSharesAddr);
    }

    /**
     * @notice Deploy Pool contract
     * @dev Pool can create its own CredoraShares if address(0) is passed
     */
    function deployPool() internal {
        console.log("Deploying Pool...");

        // Use the deployed CredoraShares
        pool = new Pool(credoraSharesAddr);
        poolAddr = address(pool);

        console.log("Pool deployed at:", poolAddr);
        console.log("Pool CredoraShares address:", pool.getCredoraSharesAddress());
    }

    /**
     * @notice Deploy verifier contracts
     */
    function deployVerifierContracts() internal {
        console.log("Deploying Groth16Verifier...");

        // Deploy the generated verifier contract
        groth16Verifier = new Groth16Verifier();
        groth16VerifierAddr = address(groth16Verifier);

        console.log("Groth16Verifier deployed at:", groth16VerifierAddr);

        console.log("Deploying Groth16VerifierWrapper...");

        // Deploy wrapper with IVerifier interface
        verifierWrapper = new Groth16VerifierWrapper(groth16VerifierAddr);
        verifierWrapperAddr = address(verifierWrapper);

        console.log("Groth16VerifierWrapper deployed at:", verifierWrapperAddr);
    }

    /**
     * @notice Deploy CreditNote721
     * @dev Requires CRD token address, will use temporary CRDVault address
     */
    function deployCreditNote721() internal {
        console.log("Deploying CreditNote721...");

        // For now, use address(0) as CRDVault address - we'll update this later
        // This is a temporary workaround for the circular dependency
        creditNote721 = new CreditNote721(credoraShares, address(0), initialOwner);
        creditNote721Addr = address(creditNote721);

        console.log("CreditNote721 deployed at:", creditNote721Addr);
    }

    /**
     * @notice Deploy CRDVault
     * @dev Requires CRD token, Pool, and NoteIssuer addresses
     */
    function deployCRDVault() internal {
        console.log("Deploying CRDVault...");

        // For now, use address(0) as NoteIssuer address - we'll update this later
        // This handles the circular dependency between CRDVault and NoteIssuer
        crdVault = new CRDVault(credoraSharesAddr, poolAddr, address(0));
        crdVaultAddr = address(crdVault);

        console.log("CRDVault deployed at:", crdVaultAddr);
    }

    /**
     * @notice Deploy NoteIssuer
     * @dev Requires CreditNote721, Pool, CRDVault, and Verifier addresses
     */
    function deployNoteIssuer() internal {
        console.log("Deploying NoteIssuer...");

        noteIssuer = new NoteIssuer(
            creditNote721Addr,
            poolAddr,
            crdVaultAddr,
            verifierWrapperAddr
        );
        noteIssuerAddr = address(noteIssuer);

        console.log("NoteIssuer deployed at:", noteIssuerAddr);
    }

    /**
     * @notice Update contract references to resolve circular dependencies
     */
    function updateContractReferences() internal {
        console.log("Updating contract references...");

        // Update CRDVault with correct NoteIssuer address
        // Note: CRDVault constructor sets immutable references, so we can't update them
        // Instead, we'll need to redeploy CRDVault with correct addresses

        console.log("Redeploying CRDVault with correct NoteIssuer address...");
        CRDVault newCrdVault = new CRDVault(credoraSharesAddr, poolAddr, noteIssuerAddr);
        address newCrdVaultAddr = address(newCrdVault);

        // Update CreditNote721 with correct CRDVault address
        // Note: CreditNote721 constructor sets immutable references, so we can't update them
        // Instead, we'll need to redeploy CreditNote721 with correct addresses

        console.log("Redeploying CreditNote721 with correct CRDVault address...");
        CreditNote721 newCreditNote721 = new CreditNote721(credoraShares, newCrdVaultAddr, initialOwner);
        address newCreditNote721Addr = address(newCreditNote721);

        // Update NoteIssuer with correct CreditNote721 address
        // Note: NoteIssuer constructor sets immutable references, so we can't update them
        // Instead, we'll need to redeploy NoteIssuer with correct addresses

        console.log("Redeploying NoteIssuer with correct CreditNote721 address...");
        NoteIssuer newNoteIssuer = new NoteIssuer(
            newCreditNote721Addr,
            poolAddr,
            newCrdVaultAddr,
            verifierWrapperAddr
        );
        address newNoteIssuerAddr = address(newNoteIssuer);

        // Update references to point to the new contracts
        crdVault = newCrdVault;
        crdVaultAddr = newCrdVaultAddr;
        creditNote721 = newCreditNote721;
        creditNote721Addr = newCreditNote721Addr;
        noteIssuer = newNoteIssuer;
        noteIssuerAddr = newNoteIssuerAddr;

        console.log("Contract references updated successfully");
    }

    /**
     * @notice Verify deployment by checking contract addresses and basic functionality
     */
    function verifyDeployment() internal view {
        console.log("Verifying deployment...");

        // Verify contract addresses are set
        require(credoraSharesAddr != address(0), "CredoraShares not deployed");
        require(poolAddr != address(0), "Pool not deployed");
        require(groth16VerifierAddr != address(0), "Groth16Verifier not deployed");
        require(verifierWrapperAddr != address(0), "VerifierWrapper not deployed");
        require(creditNote721Addr != address(0), "CreditNote721 not deployed");
        require(crdVaultAddr != address(0), "CRDVault not deployed");
        require(noteIssuerAddr != address(0), "NoteIssuer not deployed");

        // Verify contract references are correct
        require(address(pool.credoraShares()) == credoraSharesAddr, "Pool CredoraShares reference incorrect");
        require(address(noteIssuer.note()) == creditNote721Addr, "NoteIssuer CreditNote721 reference incorrect");
        require(address(noteIssuer.pool()) == poolAddr, "NoteIssuer Pool reference incorrect");
        require(address(noteIssuer.crdVault()) == crdVaultAddr, "NoteIssuer CRDVault reference incorrect");
        require(address(noteIssuer.verifier()) == verifierWrapperAddr, "NoteIssuer Verifier reference incorrect");
        require(address(creditNote721.stable()) == credoraSharesAddr, "CreditNote721 stable reference incorrect");
        require(address(creditNote721.crdVault()) == crdVaultAddr, "CreditNote721 CRDVault reference incorrect");
        require(crdVault.crdToken() == credoraShares, "CRDVault CRD token reference incorrect");
        require(crdVault.pool() == poolAddr, "CRDVault Pool reference incorrect");
        require(crdVault.noteIssuer() == noteIssuerAddr, "CRDVault NoteIssuer reference incorrect");

        console.log("Deployment verification completed successfully");
    }

    /**
     * @notice Log deployment summary
     */
    function logDeploymentSummary() internal view {
        console.log("\n=== Credora Protocol Deployment Summary ===");
        console.log("CredoraShares (CRD Token):", credoraSharesAddr);
        console.log("Pool:", poolAddr);
        console.log("Groth16Verifier:", groth16VerifierAddr);
        console.log("Groth16VerifierWrapper:", verifierWrapperAddr);
        console.log("CreditNote721:", creditNote721Addr);
        console.log("CRDVault:", crdVaultAddr);
        console.log("NoteIssuer:", noteIssuerAddr);
        console.log("Deployer:", deployer);
        console.log("Initial Owner:", initialOwner);
        console.log("===========================================\n");
    }
}
