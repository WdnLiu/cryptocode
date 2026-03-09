// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AuctionState, Commit } from "../AuctionTypes.sol";

library SettlePhase {

    event AuctionSettled(address indexed winner, uint256 winningBid);
    event Refunded(address indexed bidder, uint256 amount);
    event DepositForfeited(address indexed bidder, uint256 amount);

    function execute(AuctionState storage state) internal {
        state.settled = true;

        // 1. Find lowest bid
        uint256 lowestBid  = type(uint256).max;
        address lowestAddr = address(0);

        for (uint256 i = 0; i < state.bidders.length; i++) {
            address b = state.bidders[i];
            Commit storage c = state.commits[b];

            if (!c.revealed) {
                emit DepositForfeited(b, c.deposit);
                continue;
            }

            if (c.revealedAmt < lowestBid) {
                lowestBid  = c.revealedAmt;
                lowestAddr = b;
            }
        }

        // 2. Record winner
        if (lowestAddr != address(0)) {
            state.winner     = lowestAddr;
            state.winningBid = lowestBid;
            emit AuctionSettled(lowestAddr, lowestBid);
        }

        // 3. Refund all revealers (deposits are collateral, not payment)
        for (uint256 i = 0; i < state.bidders.length; i++) {
            address b = state.bidders[i];
            Commit storage c = state.commits[b];

            if (c.revealed && c.deposit > 0) {
                uint256 refund = c.deposit;
                c.deposit = 0;
                (bool ok, ) = payable(b).call{value: refund}("");
                require(ok, "Refund failed");
                emit Refunded(b, refund);
            }
        }
    }
}
