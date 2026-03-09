// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CommitRevealLib
 * @notice Utilities for the keccak256-based commit-reveal scheme.
 *
 * Cryptographic properties:
 *   - Hiding            (pre-image resistance)    - hash reveals nothing about the bid
 *   - Binding           (2nd pre-image resistance) - bidder cannot change (amount, secret) after committing
 *   - Collision-resistance                         - no two distinct inputs produce the same hash
 */
library CommitRevealLib {
    function computeHash(uint256 _amount, bytes32 _secret) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_amount, _secret));
    }

    function verify(bytes32 _storedHash, uint256 _amount, bytes32 _secret) internal pure returns (bool) {
        return computeHash(_amount, _secret) == _storedHash;
    }
}
