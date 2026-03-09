// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AuctionState, Commit, Phase } from "../AuctionTypes.sol";
import { CommitRevealLib } from "../libraries/CommitRevealLib.sol";

library RevealPhase {
    using CommitRevealLib for bytes32;

    event BidRevealed(address indexed bidder, uint256 amount);
    event Refunded(address indexed bidder, uint256 amount);

    function execute(AuctionState storage state, uint256 _amount, bytes32 _secret) internal {
        Commit storage c = state.commits[msg.sender];
        require(c.hash != bytes32(0), "No commit found");
        require(!c.revealed, "Already revealed");
        require(c.hash.verify(_amount, _secret), "Hash mismatch - wrong amount or secret");
        require(c.deposit >= _amount, "Deposit less than bid");

        c.revealed    = true;
        c.revealedAmt = _amount;

        uint256 excess = c.deposit - _amount;
        if (excess > 0) {
            c.deposit = _amount;
            (bool ok, ) = payable(msg.sender).call{value: excess}("");
            require(ok, "Refund failed");
            emit Refunded(msg.sender, excess);
        }

        emit BidRevealed(msg.sender, _amount);
    }
}
