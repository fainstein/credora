// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IVerifier
 * @notice Interface for Groth16 proof verification service
 * @dev Verifies zk-SNARK proofs using the Groth16 protocol
 */
interface IVerifier {
    /**
     * @notice Verify a Groth16 proof
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
    ) external view returns (bool isValid);
}
