# Subscriptor CIP Research Report

**Date:** 2026-03-26  
**Project:** `code/subscriptor` (Aiken-based Cardano smart contract wallet for pull-based subscriptions)

## Current State of Subscriptor

The project implements a **programmable subscription wallet** using Aiken validators.

### Core Features
- **Validator**: `subscriptor.ak` (with `owner_vk` and `platform_policy_id` parameters)
- **SubscriptionDetails** datum containing:
  - `lock_until`: POSIX time for next billing
  - `billable_amount`
  - `billable_unit` + `billable_unit_name` (supports ADA or other tokens)
  - `merchant_vk`: Authorized merchant
- **Actions**:
  - `Withdraw`: Owner can always withdraw funds (with signature)
  - `CollectPayment`: Merchant/platform can pull the billable amount after lock time
- **Platform fees**: Uses reference input with CIP-68 style datum for fee schedule
- **Billing cycle**: Updates datum to next month using custom date logic (`date.ak`)
- **Security**: Strict output ordering, exact amount checks, prevents merchant from being charged extra ADA

### Tech Stack
- Aiken for validators
- Custom date utilities for monthly billing
- Offchain Lucid-based transaction builders
- Uses Lucid/Ogmios/Kupo pattern

The contract is functional for basic recurring pull payments with one merchant and platform fee.

---

## Comparison to Other Ecosystems

### Ethereum (Account Abstraction)
- **ERC-4337**: Mature smart contract wallets with `UserOperation`, bundlers, and paymasters.
- Strong support for **gas abstraction**, session keys, batching, and conditional execution.
- Pull/subscription payments are easy via smart contract wallets that can execute arbitrary logic on behalf of the user.
- **Strength**: Very flexible, large ecosystem of wallets (Safe, Argent) and paymasters.
- **Weakness**: High gas costs, more centralized bundlers.

### Solana
- **Token-2022 Permanent Delegate**: Closest native primitive — allows a delegate to pull tokens without user signature for every transfer.
- Fee payer abstraction and program-derived accounts make "smart contract as wallet" more natural.
- **Agentic payments** (topic of today's SuperPay event) are actively discussed at the foundation level.
- **Strength**: Fast, cheap, native support for delegated authority.
- **Weakness**: Less expressive validation logic than Cardano's eUTxO scripts.

### Cardano Current State
Cardano has strong eUTxO scripting but lacks a standardized high-level abstraction for subscription wallets or delegated pull payments. Most solutions are custom per-project. No widely adopted CIP exists for this pattern.

---

## Gaps & Recommendations for CIP

### What Subscriptor Does Well
- Clean separation of owner withdrawal vs merchant collection
- Time-based billing with datum updates
- Platform fee support
- Strong validation against incorrect outputs/amounts

### What It Needs for a Formal CIP
1. **Standardized Datum Format** (CIP-XXXX)
2. **Support for multiple merchants** per wallet
3. **More flexible billing schedules** (weekly, custom intervals)
4. **Reference token standard** for the subscription anchor (CIP-68 extension?)
5. **Offchain discovery protocol** — how wallets find active subscriptions
6. **Security audit considerations** (replay protection, datum versioning)
7. **Wallet integration spec** (CIP-30 extension for subscription management)
8. **Multi-asset and NFT support** for billing

### Proposed CIP Structure
- **Title**: Subscription Wallet and Pull Payment Primitives for Cardano
- **Abstract**: Define a standard for programmable debit/subscription accounts using script addresses and reference tokens.
- **Specification**: Datum schemas, redeemer formats, reference token rules.
- **Rationale**: Enable recurring payments and agentic commerce without forcing users to sign every transaction.
- **Reference Implementation**: This `subscriptor` contract as starting point.

---

## Hybrid Extension Idea: Reusable Recurring Intentions

Bullet’s current intention system is powerful but nonce-based, which makes true open-ended recurring subscriptions awkward (new signatures or long pre-signed chains would be needed).

**Proposed new intention type**: `ReusableRecurring` (or `NonDestructiveIntent`)

### How it would work
- User signs a long-lived intention that grants a specific merchant permission to collect according to rules.
- The intention is **non-destructive** — it does not consume a sequential nonce on each use.
- The actual state (next billing date, amount, merchant, etc.) lives in a **Subscriptor-style persistent anchor datum** (the live UTxO).
- When the merchant submits a collection transaction, they:
  1. Include the original signed reusable intention.
  2. Reference the current anchor datum as a reference input.
  3. The validator checks that the intention is valid *and* that the datum’s rules are satisfied (time lock passed, correct amount, etc.).
  4. The datum is updated to the next billing period.

This combines:
- Bullet’s clean signed permission model
- Subscriptor’s clean stateful datum model

### Benefits
- User only signs once at subscription creation.
- Merchant can initiate pulls repeatedly without new signatures.
- Strong constraint validation from Bullet’s system.
- Clear on-chain state via the anchor datum.

### Technical Considerations
- Would require extending Bullet’s validator set with a new intention type that bypasses normal nonce consumption when a specific datum pattern is detected.
- Needs careful replay protection (perhaps using the datum’s own nonce or a version field).
- Could be proposed as either a Bullet extension or a standalone CIP that builds on both projects.

---

## Next Steps

1. Add comprehensive tests for edge cases
3. Formalize the datum and redeemer schemas
4. Write the CIP draft (potentially including the reusable intention concept)
5. Get feedback from Aiken/Cardano dev community and Intersect (including Bullet authors)

**Status**: Initial analysis complete + hybrid extension concept added. Ready for deeper review or drafting the CIP text.

---

*Report generated by Rowan. Ping me for updates, revisions, or to expand any section.*