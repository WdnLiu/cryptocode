// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AuctionState, Phase, Commit } from "./AuctionTypes.sol";
import { CommitRevealLib } from "./libraries/CommitRevealLib.sol";
import { CommitPhase } from "./phases/CommitPhase.sol";
import { RevealPhase } from "./phases/RevealPhase.sol";
import { SettlePhase } from "./phases/SettlePhase.sol";

contract ReverseAuction {
    using CommitPhase  for AuctionState;
    using RevealPhase  for AuctionState;
    using SettlePhase  for AuctionState;

    AuctionState internal state;

    // ---- Events -------------------------------------------------------------
    event AuctionCreated(address indexed owner, uint256 commitDeadline, uint256 revealDeadline);
    event ChallengeGranted(address indexed user);
    event PhaseAdvanced(Phase newPhase);

    // ---- Modifiers ----------------------------------------------------------
    modifier onlyOwner() {
        require(msg.sender == state.owner, "Not owner");
        _;
    }

    // ---- Constructor --------------------------------------------------------
    constructor(uint256 _commitDurationSecs, uint256 _revealDurationSecs) {
        state.owner          = msg.sender;
        state.phase          = Phase.COMMIT;
        state.commitDeadline = block.timestamp + _commitDurationSecs;
        state.revealDeadline = state.commitDeadline + _revealDurationSecs;

        emit AuctionCreated(state.owner, state.commitDeadline, state.revealDeadline);
    }

    // ---- Challenge gate -----------------------------------------------------
    function grantChallenge(address _user) external onlyOwner {
        state.challengePassed[_user] = true;
        emit ChallengeGranted(_user);
    }

    function verifyChallenge(address _user) external view returns (bool) {
        return state.challengePassed[_user];
    }

    // ---- Phase dispatch -----------------------------------------------------
    function commitBid(bytes32 _hash) external payable {
        require(state.phase == Phase.COMMIT, "Wrong phase");
        state.execute(_hash);
    }

    function revealBid(uint256 _amount, bytes32 _secret) external {
        require(state.phase == Phase.REVEAL, "Wrong phase");
        state.execute(_amount, _secret);
    }

    function advancePhase() external {
        if (state.phase == Phase.COMMIT) {
            require(block.timestamp >= state.commitDeadline || msg.sender == state.owner, "Commit phase not over");
            state.phase = Phase.REVEAL;
            emit PhaseAdvanced(Phase.REVEAL);
        } else if (state.phase == Phase.REVEAL) {
            require(block.timestamp >= state.revealDeadline || msg.sender == state.owner, "Reveal phase not over");
            state.phase = Phase.SETTLED;
            state.execute();
            emit PhaseAdvanced(Phase.SETTLED);
        } else {
            revert("Already settled");
        }
    }

    // ---- Owner utilities ----------------------------------------------------
    function withdrawForfeited() external onlyOwner {
        require(state.settled, "Not settled yet");
        uint256 bal = address(this).balance;
        require(bal > 0, "Nothing to withdraw");
        (bool ok, ) = payable(state.owner).call{value: bal}("");
        require(ok, "Withdraw failed");
    }

    // ---- Views --------------------------------------------------------------
    function computeHash(uint256 _amount, bytes32 _secret) external pure returns (bytes32) {
        return CommitRevealLib.computeHash(_amount, _secret);
    }

    function getPhase() external view returns (string memory) {
        if (state.phase == Phase.COMMIT) return "COMMIT";
        if (state.phase == Phase.REVEAL) return "REVEAL";
        return "SETTLED";
    }

    function getBidderCount() external view returns (uint256) {
        return state.bidders.length;
    }

    function winner() external view returns (address) {
        return state.winner;
    }

    function winningBid() external view returns (uint256) {
        return state.winningBid;
    }

    function commits(address _bidder) external view returns (bytes32, uint256, bool, uint256) {
        Commit storage c = state.commits[_bidder];
        return (c.hash, c.deposit, c.revealed, c.revealedAmt);
    }
}
