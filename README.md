# Reverse Auction - Commit-Reveal on Ethereum

## Scenario

A company (e.g. Google) is hiring a security engineer. Candidates who prove their technical
competence by completing a qualification challenge (e.g. a CTF) compete in a blind reverse
auction, each offers a salary they're willing to accept, and the lowest bid wins the role.
The problem with running this openly on-chain is that Ethereum transactions are public: if
bids were submitted in plaintext, any candidate could watch the mempool and undercut the
current lowest salary offer by 1 wei right before the deadline, making the auction trivially
manipulable.

A blockchain-based solution makes sense here because it provides a trustless settlement layer,
no intermediary decides the winner, the contract enforces the rules automaticaly. The commit-reveal
scheme solves the front-running problem by hiding bids during the submission window and only
revealing them once everyone has committed.

---

## Actors and Assumptions

| Actor | Role | Trust assumption |
|---|---|---|
| **Owner (Buyer)** | The hiring company, deploys the contract, whitelists qualified candidates | Semi-trusted, constrained by on-chain deadlines but could collude with a preferred candidate |
| **Bidders (Candidates)** | Security engineer applicants, submit hidden salary bids and reveal them in the reveal phase | Untrusted, may try to front-run, grief, or snoop on other bids |
| **Miners/Validators** | Order transactions within a block | Potentially malicious, may reorder txs for profit |

**Publicly visible on-chain:** commit hashes, deposit amounts, bidder addresses, revealed bid
amounts (after reveal phase), winner address and winning bid.

**Not visible on-chain during commit phase:** actual bid amounts, secrets.

---

## Protocol

### Happy Path

1. **Deploy** - Owner deploys the contract with commit and reveal phase durations. The contract
   starts in `COMMIT` phase immediately.
2. **Whitelist** - Owner calls `grantChallenge(address)` for each candidate who passed the
   qualification challenge (e.g. a CTF proving technical competance).
3. **Commit** - Each whitelisted bidder computes `keccak256(amount, secret)` locally and calls
   `commitBid(hash)` with an ETH deposit >= the contract's `minDeposit` threshold. The deposit
   must also be >= their actual bid amount, which is enforced at reveal time. A larger deposit
   further obscures the real bid.
4. **Advance** - Once the commit deadline passes, anyone can call `advancePhase()` to move to
   `REVEAL`. The contract enforces the deadline and reverts if it has not yet expired. Allowing
   anyone (not just the owner) to trigger this prevents the owner from holding deposits hostage
   by refusing to advance.
5. **Reveal** - Each bidder calls `revealBid(amount, secret)`. The contract recomputes the hash
   and checks it matches the stored commit. Excess deposit (deposit - bid) is refunded immediately.
6. **Settle** - After the reveal deadline passes, anyone can call `advancePhase()` again. The contract finds
   the lowest revealed bid, records the winner, and refunds all revealers their remaining deposits
   (the bid-amount portion held as collateral, the excess was already returned during reveal).
7. **Withdraw** - Owner calls `withdrawForfeited()` to collect deposits from bidders who committed
   but never revealed.

### Failure Cases

- **Bidder does not reveal** - their deposit is forfeited. They have no incentive to grief.
- **No valid bids** - all bidders fail to reveal. `winner` stays `address(0)`, no settlement occurs.
- **Hash mismatch at reveal** - bidder provided wrong amount or secret. Transaction reverts, they
  can retry with the correct values before the deadline.

---

## Threats and Attacks

### Front-Running Attack

**Scenario:** Alice submits `revealBid(500, secret)`. Bob, a malicious validator, sees this
transaction in the mempool before it gets included in a block. Bob was a committed bidder with
a bid of 1000. He replaces his reveal with `revealBid(499, secret2)` and inserts it before
Alice's transaction, winning the auction.

**Why it fails here:** Bob cant change his bid at reveal time. His bid amount was locked in
during the commit phase via the hash `keccak256(amount, secret)`. If he tries to reveal a
different amount, the contract recomputes the hash and finds a mismatch so the transaction reverts.
The binding property of keccak256 (second pre-image resistance) prevents this.

---

## Cryptographic Primitives

**keccak256 (SHA-3 variant)**
- *Hiding* - given `keccak256(amount, secret)`, it is computationally infeasible to recover
  `amount` without knowing `secret` (pre-image resistance).
- *Binding* - a bidder cannot find a different `(amount', secret')` that produces the same hash
  (second pre-image resistance), so the committed bid cannot be changed.
- *Collision resistance* - no two distinct inputs produce the same hash.

**ECDSA (implicit via Ethereum)**
- Every transaction is signed with the sender's private key, providing authentication and
  non-repudiation. Only the legitimate owner of an address can submit commits and reveals for
  that address.

---

## How to Reproduce the Demo

**Prerequisites:** Bun, MetaMask with Sepolia ETH.

1. **Install and deploy**
   ```bash
   bun install
   cp .env.example .env   # fill in PRIVATE_KEY, RPC_URL, and optionally MIN_DEPOSIT (wei, default 0.01 ETH)
   bun run deploy         # prints the deployed contract address
   ```

2. **Start the UI**
   ```bash
   bun run dev            # opens owner.html and bidder.html in the browser
   ```

3. **Whitelist a bidder** - in `owner.html`, connect MetaMask (Sepolia), paste the contract
   address, enter a bidder address and click **Grant Challenge**.

4. **Commit a bid** - in `bidder.html`, connect with the whitelisted account, paste the contract
   address, fill in a bid amount, click **Generate Random Secret**, then click **Commit Bid**
   with a deposit >= bid amount.

5. **Advance > Reveal > Settle** - in `owner.html` click **Advance Phase** to move to REVEAL.
   In `bidder.html` click **Reveal Bid** with the same amount and secret from step 4. Back in
   `owner.html` click **Advance Phase** again to settle. The winner appears in the Results section.

---

## AI Usage

We used AI (Claude) to help write the Solidity smart contract and the Bun application/deployment scripts.
