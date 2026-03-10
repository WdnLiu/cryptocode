// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AuctionState, Commit, Phase } from "../AuctionTypes.sol";

library CommitPhase {

    event BidCommitted(address indexed bidder, bytes32 hash);

    function execute(AuctionState storage state, bytes32 _hash) internal {
        require(state.challengePassed[msg.sender], "Challenge not passed");
        require(state.commits[msg.sender].hash == bytes32(0), "Already committed");
        require(msg.value >= state.minDeposit, "Deposit below minimum");

        state.commits[msg.sender] = Commit({
            hash:        _hash,
            deposit:     msg.value,
            revealed:    false,
            revealedAmt: 0
        });
        state.bidders.push(msg.sender);

        emit BidCommitted(msg.sender, _hash);
    }
}
