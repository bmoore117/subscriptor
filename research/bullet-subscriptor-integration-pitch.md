# Bullet + Subscriptor Integration Pitch

## The Opportunity

Subscriptor is a powerful, purpose-built engine for pull-based recurring payments on Cardano. It handles the state (billing schedules, usage counters, balances, lock times) cleanly and lets a platform operator aggregate and collect on behalf of merchants without users having to sign every transaction.

Bullet is Cardano's emerging account abstraction and intent system — excellent at batching, constraint validation, and letting users express complex on-chain permissions once that can be fulfilled later.

Today these two sit side-by-side but don't talk to each other. Subscriptor lives outside any larger account context. Bullet has no native strength in recurring pull payments.

The integration makes them two halves of the same thing: **the foundation of a real Cardano account abstraction stack for financial automation.**

## Core Idea (High Level)

Keep Subscriptor’s persistent datum as the single source of truth for billing state.

Move the *rules and permissions* (who can collect, under what conditions, how much, what happens next) out of the Subscriptor validator and into Bullet’s reusable, user-signed intents.

The result: recurring payments become first-class, composable objects in the account abstraction layer instead of isolated one-off contracts.

## What This Unlocks for Users & Platforms

- **Smart, set-and-forget behaviors**  
  Users sign a policy once that says things like:  
  “If my balance is low after this collection, automatically top it up from my yield position.”  
  “Sweep excess yield to pay down my loan principal faster.”  
  “Pay the bill, then immediately swap any remaining volatile tokens to stable.”  
  The platform (or a solver network) sees both the collection intent and the supporting intents and composes them into a single, optimal transaction at collection time. No extra user action required.

- **Evolving permissions without disrupting state**  
  Change merchant, adjust caps, pause/resume, delegate collection rights, or move between tiers by issuing a new signed intent. The billing history and current balance stay untouched in the datum. No mass migration of UTxOs.

- **True usage-based and prepaid models**  
  Support pay-as-you-go with per-period caps, prepaid balances that auto-deplete, or loan-style amortizing payments — all expressed as user-signed policies rather than hard-coded validator logic. The platform still does the heavy lifting of monitoring and fulfillment.

- **Network-level fulfillment**  
  Collections stop being “our backend has to monitor and submit for every subscriber.” They become fulfillable intents that a broader solver/bundler network can pick up and execute reliably, with the Subscriptor platform still in control of the business logic and user experience.

- **Cross-protocol automation**  
  A single user-signed policy can span Subscriptor billing + DEX actions + staking claims + restaking in one atomic bundle. This is the kind of “it just works” financial automation that makes Cardano feel like a real account layer.

## Strategic Positioning

This isn’t “Subscriptor on Bullet.” It’s the first real demonstration that Cardano can have a unified account abstraction story where recurring financial relationships are native, composable, and solver-friendly.

Bullet gains a high-volume, sticky use case that drives real intent traffic.  
Subscriptor stops being a standalone subscription tool and becomes the canonical recurring-payments engine inside the broader account abstraction stack.

One clean integration that makes both projects stronger and gives Cardano something Ethereum’s ERC-4337 + subscription wallets still struggle to match cleanly.

---

This is the high-level framing. We can add a one-page technical appendix if Kasey wants to go deeper, but the pitch itself stays at this altitude.