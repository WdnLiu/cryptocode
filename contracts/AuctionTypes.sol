// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

enum Phase { COMMIT, REVEAL, SETTLED }

struct Commit {
    bytes32 hash;
    uint256 deposit;
    bool    revealed;
    uint256 revealedAmt;
}

/// @dev All auction state in one struct so phase libraries can operate on it
///      via a single storage reference.
struct AuctionState {
    address owner;
    Phase   phase;
    uint256 commitDeadline;
    uint256 revealDeadline;
    mapping(address => bool)   challengePassed;
    mapping(address => Commit) commits;
    address[] bidders;
    address winner;
    uint256 winningBid;
    bool    settled;
}
