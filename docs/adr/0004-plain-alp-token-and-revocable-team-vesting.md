# ADR-0004: Plain ALP token and per-recipient vesting with team-only revocation

## Status

- ALP token: Accepted and implemented in `src/alp/ALPToken.sol` (2026-10-29).
- Vesting: Proposed (design draft, 2026-10-21). Not implemented, and not part of the ALP token audit
  scope.

## Context

The owner direction is that ALP stays simple: a plain token with no special features. Contract
decisions for ALP are made in this repository. `alphea-token` carries the business-side version of
those decisions (specification, audit package) and does not hold competing contract source.

The archived business proposals in `alphea-token` describe pre-TGE transfer restrictions, a TGE
activation switch and other token-level controls. Each of those adds a privileged role to the token
itself, which is what this design avoids.

Allocation needs are:

- one treasury that holds and distributes supply as needed;
- vesting for at most 20 recipients;
- unvested team allocations must be recoverable, for example when a team member leaves;
- investor allocations must not be recoverable.

## Decision

### ALP token

`ALPToken` is an OpenZeppelin `ERC20` with no extensions beyond the constructor:

- `constructor(string name, string symbol, uint256 totalSupply, address treasury)` mints the entire
  fixed supply to `treasury` once and rejects a zero treasury or zero supply.
- 18 decimals.
- No owner, no role, no `mint`, no `burn`, no pause, no blacklist, no fee or tax, no transfer
  limit, no proxy and no upgrade path. Every holder transfers freely from deployment.

`treasury` is a reviewed Safe. All distribution (exchange, liquidity, ecosystem, marketing, funding
vesting wallets) is an ordinary Safe-signed transfer out of that Safe. The security of the supply is
therefore the security of the Safe: its owners, threshold and signer key custody.

There is no TGE switch. Supply that must not move before TGE stays in the Safe or in vesting wallets
until then; the token does not enforce it.

### Vesting

Each recipient gets one `ALPVestingWallet`, which extends OpenZeppelin `VestingWalletCliff`
(OpenZeppelin 5.4.0, already pinned here):

```text
constructor(
    address beneficiary,     // Ownable owner; receives released ALP
    uint64  startTimestamp,  // vesting start
    uint64  durationSeconds, // linear vesting length from start
    uint64  cliffSeconds,    // nothing vests before start + cliff
    IERC20  alp,             // the only token revoke can act on
    address revoker          // team: the treasury Safe; investor: address(0)
)
```

All parameters are immutable. The schedule is the unmodified OpenZeppelin cliff-then-linear curve.

`revoke()`:

- callable only by `revoker`; reverts on a wallet whose `revoker` is `address(0)`, so investor
  wallets are provably non-revocable;
- callable once;
- first releases everything vested up to the revocation block to the beneficiary;
- then transfers the remaining (unvested) ALP balance to `revoker`;
- after revocation the schedule reports the wallet as fully vested over whatever it still holds, so
  `releasable` is the residual balance, which is normally zero. ALP sent to a revoked wallet by
  mistake can still only go to the beneficiary, never back to the revoker.

Invariants:

- `vested(t)` is non-decreasing in `t` until revocation.
- At revocation, the beneficiary has received exactly `vested(revocationBlock)`; revocation can
  never take ALP that had already vested.
- `released + revokedAmount + balance == totalFunded` for ALP at all times.
- A wallet with `revoker == address(0)` has the same behaviour as a plain `VestingWalletCliff`.

Recipient handling follows the OpenZeppelin wallet:

- the beneficiary may transfer ownership (key rotation); revocation still pays vested ALP to the
  current owner;
- `release` is callable by anyone and always pays the owner;
- native currency or other tokens sent to the wallet vest normally and are not revocable.

### Deployment and funding

- A Forge script deploys `ALPToken` and the vesting wallets from one reviewed public JSON input
  (name, symbol, supply, treasury Safe, and per recipient: beneficiary, amount, start, cliff,
  duration, revocable). It signs nothing with a key held in this repository.
- Funding is a single batched Safe transaction from the treasury Safe to every vesting wallet. The
  script emits the batch for review; it never sends it.
- Deployment evidence follows ADR-0002: exact constructor arguments, source commit, runtime hashes,
  and Sourcify/BscScan verification of every deployed address.

### Testing

Unit, fuzz and invariant coverage before review:

- token: fixed supply at the treasury, zero-address and zero-supply refusal, absence of any
  privileged function;
- vesting: cliff and end boundaries, linear accrual, release to the current owner, revoke access
  control, single use, refusal on investor wallets, vested-never-revoked, the conservation
  invariant above under arbitrary release/revoke/time interleavings, and post-revocation deposits.

## Consequences

- The token itself has no centralisation surface. The intended central powers are the treasury
  Safe's custody of undistributed supply and its right to revoke unvested team allocations. Both
  are listed for the auditor as intended features.
- The audit surface is one standard ERC-20 and one small `VestingWalletCliff` extension.
- There is no on-chain pre-TGE lock. If one is required later, it must be a separate decision,
  because it reintroduces a privileged token role.
- A beneficiary who loses their key loses access to their allocation; a revocable wallet's unvested
  part can still be recovered by the treasury, an investor's cannot.
- Up to 20 wallets are deployed individually; there is no Merkle root to generate or publish.

## Open inputs

These must be fixed before implementation is reviewed:

- token name, symbol and total supply;
- the treasury Safe address, owners and threshold;
- the allocation table: each recipient's address, amount, start, cliff, duration, and
  team (revocable) or investor (non-revocable);
- target chain(s) and the TGE date;
- whether investors are also covered by the same wallet type (this draft assumes yes, with
  `revoker == address(0)`).
