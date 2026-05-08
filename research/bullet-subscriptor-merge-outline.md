# Bullet + Subscriptor Merge: Technical Outline

**Date:** 2026-05-05  
**Status:** Early technical sketch for Kasey discussion  
**Goal:** Merge Subscriptor’s core logic into Bullet so that recurring pull payments become a first-class, composable primitive inside Cardano’s account abstraction layer.

## Strategic Framing for the Conversation

We are not bolting Subscriptor onto Bullet. We are **merging Subscriptor’s state machine into Bullet** so that:

- Bullet becomes the complete account abstraction story for Cardano.
- Recurring financial relationships (subscriptions, usage-based billing, card-authorized pulls) are native, solver-friendly, and composable with the rest of the on-chain world.
- Both projects stop being “dormant side projects” and become the canonical implementation of financial automation on Cardano.

This gives Cardano something Ethereum’s ERC-4337 + subscription wallets still struggle to deliver cleanly: a unified intent layer where recurring pull payments are just another kind of reusable, policy-driven action.

## Core Architectural Principle

**Subscriptor keeps the persistent, minimal state.**  
**Bullet becomes the policy and execution layer.**

We move the *rules* (who can collect, under what conditions, how much, what happens next, how policies evolve) out of the Subscriptor validator and into Bullet’s reusable intent system. The Subscriptor datum shrinks to a thin, trustworthy anchor that only records what has actually happened.

This split mirrors the best account abstraction designs: a small, auditable state machine + a rich, user-signed policy layer that solvers can fulfill.

## The Two Modes We Will Eventually Surface

(We lead with the pure composability story first, then drop the card tie-in as the “now picture this” escalation.)

**Mode 1 – Pure-crypto recurring subscriptions (decentralized guarantees)**  
User visits a website, wallet plugin generates a Subscriptor mint + first collection. Everything is on-chain, transparent, and enforces billing fairness without a card layer. This is Subscriptor’s original strength.

**Mode 2 – Open-ended account abstraction for TradFi/card connectivity**  
A card is tied to an open-ended subscription with no time lock (only daily/monthly spending limits). The authorized collector address (the card issuer/processor) can initiate direct collections at any time. Lose the card? Connect wallet and invalidate the subscription. This is how traditional cards work against bank accounts.

An issuer/processor like Colossus does not primarily care about Mode 1. What matters to them is that we can support Mode 2: the ability to randomly charge a Cardano account for stables or any token of choice.

## Technical Merge Outline

### 1. Subscriptor Datum Shrinks (State Only)

Current heavy datum fields that move to Bullet intents:
- `merchant_vk` / authorized collector
- Fixed amount or rate calculation logic
- Hard-coded caps and pause logic

Remaining thin anchor datum (example Aiken sketch):

```aiken
pub type SubscriptorAnchor {
  version: Int,
  lock_until: Int,
  usage_counter: Int,
  remaining_balance: Int,      // or Option<Int> for prepaid
  schedule_params: Schedule,   // still needed for “next due” calculation
  // minimal safety bounds only
}
```

Validator responsibilities reduced to:
- “New lock time must advance correctly”
- Version check (prevents replay of old intents)
- Basic bounds (no negative balances, etc.)
- State transition only — no business policy

### 2. Bullet Gains a Reusable Recurring Intent Type

New intention variant (non-destructive / reusable):

```aiken
pub type RecurringCollection {
  anchor_ref: ReferenceInput<SubscriptorAnchor>,
  collector: VerificationKey,
  amount_fn: AmountFunction,      // usage × rate, capped, etc.
  time_constraint: TimeWindow,
  version: Int,
  // optional: daily_cap, monthly_cap, auto_top_up_intent_ref, etc.
}
```

Key Bullet mechanisms leveraged:
- `RefConVal` + `datum_field` path selection → pulls live `usage_counter`, `remaining_balance`, `lock_until` into `temp_val` without spending the anchor.
- `SomeTwo((policy, asset))` dynamic value constraints → output amount computed at fulfillment time.
- Reusable intent + versioned datum → platform can publish a superseding intent to change merchant, adjust caps, pause, or delegate collection rights. Old intent rejected on version mismatch.
- `intentionGroups` + aggregation → hundreds of collections batched in one tx while still honoring per-user policies.

### 3. Collection Flow (Mode 1 – Pure Crypto)

1. User signs two Bullet intents + creates thin Subscriptor anchor in one transaction.
2. At collection time the platform/solver sees the active `RecurringCollection` intent for that anchor.
3. Solver builds tx that:
   - References the Subscriptor anchor as reference input.
   - Includes the signed intent.
   - Bullet constraint engine validates amount via `temp_val`, checks time window, version, caps.
   - Subscriptor validator only confirms final state transition is valid.
4. User never signs again unless they change policy.

### 4. Collection Flow (Mode 2 – Card / Open-Ended)

1. User creates thin Subscriptor anchor with **no lock_until** (or lock_until = now) and a daily/monthly cap.
2. Signs a `RecurringCollection` intent that names the card issuer/processor’s address as the collector.
3. When the card is swiped, the issuer/processor (or their solver) simply submits a collection against that intent.
4. Lose the card → user connects wallet and publishes a new intent that invalidates the old collector (or sets cap to zero). No need to touch the anchor datum.
5. This is deliberately less “decentralized” than Mode 1 — that is the point. We trade some guarantees for card distribution.

### 5. What Needs to Be Built (Concrete Work Items)

**Bullet side**
- New `RecurringCollection` (or `NonDestructiveRecurring`) intention type in `intention_auth` validator and off-chain types.
- Support for reusable (non-nonce-consuming) intents.
- `RefConVal` + `datum_field` integration for Subscriptor anchor fields.
- Policy versioning and superseding logic.
- Optional: standardized CIP for reusable recurring intents so other protocols can reuse the pattern.

**Subscriptor side**
- Minor validator update to accept intent reference + version check instead of embedded merchant_vk/amount fields.
- Datum migration path (or accept both old and new datum shapes during transition).
- Off-chain platform changes: intent storage, policy versioning UI, solver-friendly submission path.

**Joint / Platform**
- Unified subscription creation flow that produces both the thin anchor and the initial Bullet intent(s).
- Solver/bundler integration so collections can be fulfilled by the network rather than a single platform backend.
- (Stretch) Cross-protocol intents: one signed policy that spans Subscriptor billing + DEX swaps + staking claims in a single atomic bundle.

### 6. Why This Merge Makes Sense

- Subscriptor stops being a standalone subscription tool and becomes the canonical recurring-payments engine inside the broader account abstraction stack.
- Bullet gains a high-volume, sticky use case that drives real intent traffic and demonstrates production value.
- Cardano gets a unified story: “We have account abstraction, and recurring financial relationships are first-class citizens.”
- The two-mode model (pure crypto vs. card-connected open pulls) gives us a credible path to talk to real card networks without over-promising decentralized guarantees where they don’t belong.

## Suggested Conversation Flow with Kasey

1. Lead with the unified account abstraction story and the composability win.
2. Show the technical merge outline above (keep it high-level first).
3. Emphasize that both projects move forward together instead of staying dormant.
4. Once he’s engaged, drop the Mode 2 / card tie-in as the escalation: “Now picture this — we can also support open-ended pulls that a card processor can just charge whenever they want, with simple daily caps. Lose the card, invalidate it from your wallet. That’s how real cards work.”
5. Close by noting that this positions Cardano (and IOG) to be relevant when someone like Colossus or another acquirer-facing player eventually looks for a non-Ethereum settlement option.

---

*This document is intentionally concise for the first discussion. We can expand any section into full Aiken interfaces or CIP drafts once we have alignment.*