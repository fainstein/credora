// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVerifier} from "../interfaces/IVerifier.sol";
import {Groth16Verifier} from "./generated/verifier.sol";

/**
 * @title Groth16VerifierWrapper
 * @notice Wrapper contract that implements IVerifier interface and delegates to official Groth16Verifier
 * @dev This wrapper allows the system to use the official Groth16Verifier through a standardized interface
 */
contract Groth16VerifierWrapper is IVerifier {
    /// @notice The official Groth16Verifier contract
    Groth16Verifier public immutable groth16Verifier;

    /**
     * @notice Constructor
     * @param _groth16Verifier Address of the official Groth16Verifier contract
     */
    constructor(address _groth16Verifier) {
        require(_groth16Verifier != address(0), "Invalid verifier address");
        groth16Verifier = Groth16Verifier(_groth16Verifier);
    }

    /**
     * @notice Verify a Groth16 proof by delegating to the official verifier
     * @param _pA The proof's A point [x, y]
     * @param _pB The proof's B point [[x1, x2], [y1, y2]]
     * @param _pC The proof's C point [x, y]
     * @param _pubSignals The public signals array (5 elements)
     * @return isValid True if proof is valid
     */
    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[5] calldata _pubSignals
    ) external view override returns (bool isValid) {
        return groth16Verifier.verifyProof(_pA, _pB, _pC, _pubSignals);
    }
}
