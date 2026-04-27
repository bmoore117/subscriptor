# Viability assessment of Cardano projects
_Exported on 4/27/2026 at 09:40:37 EDT from Cursor (3.2.10)_

---

**User**

I've got this project in @subscriptor/ which is an attempt to build pull-style transactions on the cardano blockchain, written in aiken with some working off-chain code in lucid-evo. @subscriptor/subscriptor-cip-research.md is a report containing some exploratory research around possibly combining my idea with the ideas in @bullet/ which is a project by a friend of mine to build a sort of account abstraction on cardano. can you read through the code in subscriptor, the report, and the code in bullet and give me your assessment as to how viable it would be to incorporate my idea?

---

**Cursor**

Let me start by reading the research report and exploring both codebases in parallel.

I've now read through the research report, every on-chain and off-chain file in subscriptor, and the full bullet codebase. Here's my assessment.

---

## Viability Assessment: Incorporating Subscriptor into Bullet

### What Each Project Brings

**Subscriptor** is a clean, focused pull-payment validator. A CIP-68 anchor NFT holds `SubscriptionDetails` (lock time, amount, currency, merchant). After `lock_until` passes, *anyone* can build a `CollectPayment` transaction that splits funds to platform + merchant + contract change with an updated datum. The owner retains a separate `Withdraw` path. It's simple and it works.

**Bullet** is a sophisticated account-abstraction layer. Users own script addresses routed through a proxy pattern: a tiny `proxy_spend` withdrawal script reads a `ProxyState` reference datum that points to specialized auth validators (hot, cold, wallet, intention, change, delete). The intention system lets users sign a constraint-rich payload *once* and have relayers submit it — with replay protection via sequential or parallel nonces.

### The Core Tension

Your research report identifies this correctly: Bullet's intention system is **nonce-based**, which makes open-ended recurring pulls awkward. A subscription needs a merchant to pull *repeatedly* from a single authorization. In Bullet today, that would require either:

- Pre-signing a chain of sequential-nonce intentions (brittle, finite)
- A new parallel-nonce intention per billing cycle (requires user action each time)

Neither fits the "sign once, merchant pulls forever" model that makes subscriptor useful.

### Three Integration Paths (Ranked by Viability)

#### Path A: New Subscription Auth Validator (Most Viable)

Bullet's proxy pattern is explicitly designed for modularity — `ProxyState` already has six credential slots routing to different auth scripts. The cleanest integration is:

1. **Add a `subscription_auth.ak`** as a new withdrawal-based auth validator, analogous to `hot_auth.ak` or `intention_auth.ak`.
2. **Route through the proxy** by either adding a 7th credential slot to `ProxyState` or reusing the `intent_auth_contract` slot with a wrapper.
3. The new validator would:
   - Verify a long-lived signed subscription permission (similar to a `SignedIntention` but without nonce consumption)
   - Read the anchor datum from a script UTxO (like subscriptor does today)
   - Check `lock_until` has passed against the validity interval
   - Validate the output ordering: platform fee → merchant → contract change with updated datum
   - Advance `lock_until` to the next billing period
4. **Replay protection** comes from the **datum state transition itself** — `lock_until` advances on each pull, so the same authorization can't extract twice for the same period. This replaces the nonce.

**Why this works well:**
- Bullet's compile-time hash chain (`compile.sh`) already handles adding new validators
- The proxy pattern means you don't touch `bullet.ak` or `bullet_nonce.ak` at all
- The subscription UTxO can live at the bullet account address (`Script(bullet_hash)` payment + `Script(user_stake)` stake), so it's a first-class bullet account asset
- You could even tag it with `UtxoStates` — perhaps a new `Subscription` variant alongside `Control`, `ParallelNonce`, and `Vault`
- Hot auth's `filter_hot_inputs` could be extended to also exclude subscription anchors, giving them vault-like protection

**Estimated effort:** Medium. You'd write ~200-300 lines of Aiken for the new auth validator, extend `ProxyState` and `UtxoStates` types, update `compile.sh`, and add off-chain tx-building code. The hardest part is getting the proxy routing and reference-input plumbing right, but bullet's existing auth validators are good templates.

#### Path B: Extend the Intention Constraint System (Harder, More Powerful)

This is the "ReusableRecurring" idea from your report. You'd add a third nonce variant:

```aiken
type Nonce {
  Sequential(Int)
  Parallel(OutputReference)
  Recurring(ByteArray)  // e.g. subscription anchor asset name
}
```

The `fold_intent_counts` logic in `intention_utils.ak` would need a new branch that:
- Skips nonce consumption for `Recurring`
- Instead validates that a referenced datum's state has advanced
- Checks that constraints match the subscription's rules

**Why this is harder:**
- `intention_utils.ak` is already the most complex part of bullet (~400+ lines of fold logic with `temp_val` plumbing, bitmap indexing, and multi-user batching)
- The constraint system (`Constraint` enum) currently supports output/input/mint/time matching but **not arbitrary datum field comparison** — you'd need to add constraint types like `DatumFieldGt` or similar
- Changes to the core intention fold risk regressions across all of bullet's existing functionality
- The `SignedIntention` serialization format would need to accommodate the new nonce type, affecting off-chain signing code

**Upside:** This would make recurring subscriptions a native intention primitive, enabling batching of subscription pulls alongside other intentions in a single transaction. A relayer could process 20 subscription collections in one tx using the existing multi-user batching infra.

**Estimated effort:** High. Significant changes to `intention_types.ak`, `intention_utils.ak`, `intention_auth.ak`, `constraint_utils.ak`, and all off-chain signing/building code.

#### Path C: Parallel Deployment with Cross-Recognition (Simplest but Weakest)

Keep subscriptor as a standalone validator. Make it recognize bullet account addresses so that:
- A bullet user can fund a subscriptor script UTxO
- The subscriptor validator checks that the funding address was a bullet account (via reference input or signature)
- Withdrawal goes back to the bullet account address

**Why this is weak:** You lose bullet's security model entirely for subscription funds. The subscription UTxO lives at subscriptor's script address, not the bullet account address, so hot/cold/vault protections don't apply. It's really just "use both projects separately."

### My Recommendation

**Path A is clearly the sweet spot.** It leverages bullet's modularity without touching its core, preserves subscriptor's clean datum-driven billing model, and gives you full bullet account security for subscription funds. The datum-as-replay-protection insight from your report is sound — if `lock_until` must strictly advance on each pull, and the validator enforces it, you don't need nonces at all.

### Practical Concerns

1. **Bullet is more complex than subscriptor by an order of magnitude.** The proxy routing, compile-time hash dependencies, and multi-validator architecture mean the integration surface area is real. Your friend would likely need to be involved — at minimum to approve the `ProxyState` extension.

2. **The fee model needs reconciliation.** Subscriptor uses `fee_percentage_basis_points` divided by 1000 (really per-mille). Bullet has no concept of platform fees. You'd need to decide whether the fee schedule lives in the subscription auth validator or becomes a bullet-level concept.

3. **Testing infrastructure.** Bullet has good unit/fuzz tests in Aiken. Subscriptor's off-chain tests are manual scripts. An integrated solution needs the kind of emulator-based testing bullet uses in `bulletEdd25519.ts`.

4. **The `date.ak` situation.** The on-chain code currently uses `determine_first_of_next_month_testing` which just adds 5 minutes. Before any serious integration, you'd need to switch to the real calendar logic (the non-`pub` `determine_first_of_next_month` already exists but isn't wired up).

5. **Subscriptor's repo hygiene.** The Next.js app is still the gift card example, `README.md` describes Adalicious, and `scripts/create-subscription-datum.js` is out of date vs the on-chain types. Cleaning this up (as your report's "Next Steps" notes) would be a prerequisite for any serious collaboration.

### Bottom Line

**It's viable, and Path A is the right approach.** The architectural fit is genuinely good — bullet was designed to be extensible through new auth validators, and subscriptor's pull model maps naturally onto a withdrawal-based auth script. The main risk isn't technical feasibility but coordination complexity: you're extending someone else's carefully designed multi-validator system, so alignment on the `ProxyState` extension and security invariants matters. I'd suggest writing a design doc for the subscription auth validator and getting your friend's buy-in on the proxy routing before writing code.

---

**User**

one thing that I'm aware of is that bullet is designed to be very lightweight computationally in order to realistically support the kind of multi-intention batching per tx that it does; there's only a certain amount of memory and compute that are available to use per-block in cardano. while I tried to keep subscriptor fairly light, I was insistent on putting the date logic on-chain as I do think that's a unique capability to have and it makes the system overall more elegant.

The date algorithms I found too are pretty optimized, operate in constant time, and are much better than the simple recursive approach used in other date calculation systems. However, they may still make subscriptor a little computationally heavy. I don't actually have any numbers or figures on that, we could probably gather some by running aiken tests and looking at the memory and cpu printouts, but what I'm driving at is does the subscriptor approach seem much more computationally heavy than what bullet is already doing?

---

**Cursor**

Great question. Let me look at the actual on-chain logic in both projects to give you a grounded comparison. I want to see the real date algorithms, the intention fold, and the constraint engine side by side.

Let me also look at the signature checking and the hot/wallet auth validators to understand their per-invocation cost.

Okay, now I have a detailed picture of both codebases' computational profiles. The short answer is: **the date math is not a concern at all**, and subscriptor as a whole is significantly lighter than what bullet already does per intention. Let me break down why.

## The Date Algorithm is Trivially Cheap

Your `determine_date` function from the Hinnant algorithms is roughly 15 integer operations — divisions, multiplications, additions, and a couple of conditionals:

```13:46:subscriptor/validators/date.ak
fn determine_date(p_time: Int) -> DateTime {
  let z = p_time / 86400 + 719468
  let era =
    if z >= 0 {
      z
    } else {
      z - 146096
    } / 146097
  let doe = z - era * 146097
  // [0, 146096]
  let yoe = ( doe - doe / 1460 + doe / 36524 - doe / 146096 ) / 365
  // ... snip ...
  DateTime { posix_time: p_time, year: final_y, month: m, day_of_month: d }
}
```

Then `last_day_of_month_common_year` is a chain of up to 12 integer comparisons, `is_leap` is 3 modulo ops, and the final arithmetic is 2 more operations. The whole `determine_first_of_next_month` pipeline is maybe **25-30 integer operations total**.

In the Plutus cost model, integer arithmetic is among the absolute cheapest builtins. An `addInteger` is roughly ~100K CPU units, a `divideInteger` maybe ~200-400K. So the entire date calculation is in the ballpark of **5-10 million CPU units**.

## Now Compare That to What Bullet Does Per Intention

For every single intention in a batched transaction, bullet's `intention_auth` runs:

1. **CBOR serialization** of the intent (`serialise(intent)`) — typically millions of CPU units depending on data size
2. **Two byte concatenations** (prefix + serialized + postfix)
3. **`blake2b_256` hash** of the result — ~5-20 million CPU units depending on input size
4. **At least one `verify_ed25519_signature`** — this is the big one, roughly **50-100 million CPU units** per signature. With Schnorr or ECDSA it's even more expensive.

```196:226:bullet/lib/intention_utils.ak
pub fn fold_intent_counts(
  // ...
) -> Bool {
  // ... per user:
  // ref_control_datum scan
  // fold_constraints (each constraint scans inputs/outputs/ref_inputs)
  // sig_checker: serialise -> concat -> concat -> blake2b_256 -> verify_ed25519
  // fold_inputs: scan all inputs, decompose values, fast_combine_natural_values
  // fold_outputs: scan outputs, fast_combine_output_value
  // value_compare
```

Then the constraint engine (`fold_constraints` calling into `handle_inp_constraint`/`handle_out_constraint`) does linear scans of inputs or outputs for each constraint, with address matching, value checking, and datum field selection via `select_field` (which walks constructor fields by index). The value accounting logic (`fast_combine_natural_values`, `fast_combine_output_value`) does sorted-map merges over policy IDs and asset names.

**A single Ed25519 signature verification costs roughly 10-20x more than your entire date calculation.** And bullet runs at least one per intention, often more for quorum.

## What About the Rest of Subscriptor's CollectPayment?

The non-date parts of `CollectPayment` are:

- Two linear scans of inputs (finding the anchor datum, computing `contract_input_total`)
- One linear scan of reference inputs (finding the platform fee schedule)
- Several `quantity_of` calls (dict lookups)
- Three indexed output accesses (`list.at(outputs, 0/1/2)`)
- A fee calculation (one multiply, one divide, one `math.max`)
- Datum deserialization and field comparisons

This is **structurally similar** to what bullet does per-user in `fold_inputs` and `fold_outputs` — scanning inputs, accumulating values, checking addresses, deserializing datums. It's arguably simpler because subscriptor has fixed output ordering (platform at 0, merchant at 1, change at 2) instead of bullet's more flexible constraint-driven matching.

## The Real Picture

If we were to put rough proportional costs:

| Operation | Approx CPU | Where |
|---|---|---|
| Date calculation (full) | ~5-10M | Subscriptor only |
| One Ed25519 verify | ~50-100M | Bullet, per intention |
| blake2b_256 hash | ~5-20M | Bullet, per intention |
| CBOR serialise(intent) | ~5-15M | Bullet, per intention |
| Input list scan (5 inputs) | ~2-5M | Both |
| Value map merge | ~2-5M | Bullet, per user |

A single bullet intention with one signature already costs in the range of ~80-150M CPU units just for the crypto. The date math would add roughly 5-7% to a subscriptor collection transaction's budget — and that's comparing it to subscriptor's own cost, not bullet's. In the context of bullet's per-intention overhead, it's noise.

## One Nuance Worth Noting

Your testing function actually already runs the full date computation and throws it away:

```95:102:subscriptor/validators/date.ak
pub fn determine_first_of_next_month_testing(p_time: Int) -> Int {
  let datetime = determine_date(p_time)
  let last_day = last_day_of_month(datetime.year, datetime.month)
  let remainder = last_day - datetime.day_of_month + 1
  let time = datetime.posix_time + remainder * 86400
  trace time
  p_time + 300000 + time - time
}
```

The `+ time - time` forces evaluation, so you're already paying for the date math in every `CollectPayment` today. Switching to the real `determine_first_of_next_month` would cost exactly the same — it just uses the computed `time` directly instead of discarding it.

## Bottom Line

Your instinct to keep the date logic on-chain is well-justified. It's pure constant-time integer arithmetic, which is about the cheapest thing you can do in Plutus. The dominant costs in any integrated system would be signature verification, CBOR serialization, and hashing — all of which are bullet's concern, not subscriptor's. If anything, a subscription collection is *lighter* than a typical bullet intention because it doesn't need crypto operations (the merchant's authorization comes from the datum rules, not from signature verification).

Running `aiken check` with the `--trace-level verbose` flag would give you exact mem/cpu numbers for your test cases if you want to confirm, but I'd be surprised if the date logic even registers as a meaningful fraction.

---