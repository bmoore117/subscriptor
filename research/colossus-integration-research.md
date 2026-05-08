# Colossus Stablecoin Card Network - Cardano Integration Research

**Date:** 2026-05-05  
**Status:** Early-stage opportunity assessment  
**Context:** Follow-up to Bullet + Subscriptor recurring payments work; exploring physical card / acquirer-layer plays

## What Colossus Actually Is

Colossus (founded 2025 by Joseph Delong, former SushiSwap CTO and Teku consensus client contributor) is attempting to build a **sovereign credit card network** that settles in stablecoins instead of traditional bank rails. [Founders Inc. profile]

Key claims from available coverage:

- Runs on its own Ethereum Layer-2 network. [Decrypt, March 2026]
- Vertically integrates the roles of issuer, processor, and settlement network. [Decrypt]
- Uses cryptographic signatures instead of traditional bank approval for transactions. [Decrypt]
- Preserves the **acquirer** role for merchants so existing point-of-sale terminals and EMV flows continue to work unchanged. [Decrypt]
- Merchants receive fiat via their existing acquirer; Colossus delivers stablecoins to the acquirer (or the acquirer's designated settlement address). [Decrypt]
- Strong emphasis on minimal KYC/AML requirements by interpreting the GENIUS Act aggressively, enabling "KYC-less" cards in some cases. [Decrypt]
- Goal: make stablecoin cards feel like normal cards in the wallet while giving users full on-chain control. [Decrypt]

They have raised a small pre-seed round of $500,000 at a $10 million valuation. The team is tiny (reported as four people) and the project remains pre-launch. [Decrypt] The public website (colossus.credit) currently functions as a minimal placeholder. [Direct observation]

## The Real Bottleneck: Acquirers, Not the Tech Stack

Colossus' hardest problem is **not** building another Ethereum L2. It is getting acquirers (Worldpay, Fiserv, Stripe, etc.) to accept their network as a valid card scheme.

- Acquirers already have relationships with millions of merchants and own the terminal estate.
- They handle the "last mile" fiat payout to merchants.
- Colossus wants to collapse the issuer/processor/brand layers above them while leaving the acquirer untouched.

This is why their pitch centers on plugging into existing EMV standards and point-of-sale terminals. They are not asking merchants to install new software. They are asking acquirers to route traffic for a new BIN range (or equivalent) to Colossus' network endpoint. [Synthesis from Decrypt reporting]

## Card Routing Mechanics (Quick Primer)

- **BIN** (Bank Identification Number): The first 6–8 digits of a card number. This is the primary routing key. Networks and processors maintain large tables mapping BIN ranges to issuers/processors. (Standard industry practice)
- **AID** (Application Identifier) on EMV chip cards: A separate identifier that tells the terminal which application (Visa, Mastercard, Amex, or a new scheme) to talk to and how to perform cryptographic operations. This is more standardized than raw BINs and is managed through EMVCo.
- EMVCo is the closest thing the card world has to "ICANN for payment applications," but it is industry-consortium driven, not a neutral registry like ICANN. Getting a new AID accepted still requires coordination with acquirers and terminal vendors.
- Different schemes (Amex, Discover, JCB, private label) already use non-standard lengths or prefixes. The system tolerates this because every major acquirer and terminal has configurable routing tables.

In short: cards are crufty and table-driven. There is no elegant global hostname equivalent. New schemes succeed by convincing acquirers to add a row to their routing tables, not by elegant protocol design. (General payments industry knowledge)

## Colossus' Settlement Model

From the reporting:

- Colossus intends to send **stablecoins** to the acquirer (or the acquirer's on-chain settlement address). [Decrypt]
- The acquirer then handles the fiat conversion and payout to the merchant. [Decrypt]
- No evidence they are building their own off-ramp/exchange partnership for this step — they appear to be relying on acquirers already having stablecoin handling or partners who do. (Inferred from reporting)
- Merchants never see or handle crypto. This is deliberate. Direct quote from founder Joseph Delong:

> “I don’t know who convinced all these crypto people that merchants want stablecoins. They generally want something that they can pay their suppliers with.” [Decrypt, March 2026]

This is the cleanest part of their model for a potential Cardano integration.

## Cardano Fit and Minimum Viable Surfaces

If we wanted Subscriptor (or a broader Cardano account layer) to be a viable settlement/issuance option that Colossus or similar acquirer-facing players could plug into, here is the minimum set of capabilities they would realistically need:

1. **Script-based / Multi-sig Account Abstraction (today)**
   - Native multi-signature and Plutus script accounts already exist on Cardano.
   - We can express spending policies, time locks, and delegation rules without CIP-0038.
   - CIP-0038 (dcSpark's account abstraction proposal) would give nicer "smart contract as wallet" semantics but requires a hard fork. Not happening soon. (Our assessment based on public CIP status)

2. **Recoverability / Social Recovery**
   - Currently weak on Cardano. Multi-sig helps, but true social recovery or passkey-style flows are missing.
   - This is a gap Colossus (and any serious card product) would care about. Users expect "I lost my phone, here's how I get my card back." (Our assessment)

3. **Recurring / Pull Payment Primitives (Subscriptor) — Two Distinct Modes**
   - **Mode 1 — Pure crypto recurring subscriptions (decentralized guarantees)**: A user visits a website that accepts direct crypto wallet payments. A checkout plugin generates a Subscriptor mint + first collection transaction. The user signs it in their wallet. Everything is on-chain, transparent, and enforces billing fairness without a card layer. This is Subscriptor's original strength.
   - **Mode 2 — Open-ended account abstraction for TradFi/card connectivity**: The user has a card tied to an open-ended subscription with no time lock on the next collection (only daily/monthly/etc. spending limits). The authorized merchant/collector address (the card issuer or processor) can initiate direct collections at any time. If the user loses the card, they connect their wallet and invalidate the subscription. This is the model traditional cards use against bank accounts.
   - An issuer/processor like Colossus does not primarily care about the pure-crypto decentralized subscription use case. What matters to them is that Subscriptor can also support the open-ended pull model they need: the ability to randomly charge a Cardano account for stables or any token of choice. (Our assessment + current thread clarification)

4. **Intent / Solver-Friendly Execution**
   - If Bullet or a similar intent layer exists, the ability for a network-level solver to fulfill collections without the user signing every transaction.
   - Batch + constraint validation so one on-chain action can handle payment + any required swaps or top-ups. (Our assessment, tying to prior Bullet + Subscriptor work)

5. **Stablecoin / Asset Settlement Interface**
   - For the card use case (Mode 2 above), settlement is straightforward: the card processor/issuer, as the authorized collector on the open-ended subscription, simply initiates a collection that transfers stables (or the token of choice) from the user's Cardano script account directly to a Colossus-controlled Cardano wallet/address.
   - No complex on-chain escrow is required because the card network itself absorbs the risk and provides the settlement guarantee to the downstream acquirer and merchant.
   - The pure-crypto subscription mode (Mode 1) can use tighter constraints and visibility, but the card-connected mode deliberately trades some of those decentralized guarantees for the convenience and distribution of the traditional card rails. (Our assessment + current thread clarification)

6. **Lightweight On-Chain Identity / Attestation**
   - Some minimal way to link a Cardano address/script to a card identity without full KYC on-chain (they seem to want to avoid this). (Our assessment, based on their GENIUS Act stance)

## Reality Check

- **No public integration surface exists yet.** Colossus has no developer docs, SDKs, or published APIs. They are still in the "box of goodies" phase with physical POS hardware. [Decrypt]
- **Ethereum-centric.** All public discussion is about their L2. No mention of multi-chain support. (Observation from available coverage)
- **US adoption is genuinely hard.** PCI compliance, acquirer relationships, and regulatory uncertainty around new card schemes are real barriers. This is why many crypto card plays focus on Latin America, Dubai, or Southeast Asia first. (Our assessment, consistent with broader market patterns noted in Decrypt)
- **The acquirer is the kingmaker.** Whoever controls the terminal routing wins distribution. Building a better on-chain settlement layer is secondary to getting a row in the acquirer's routing table. (Our synthesis)

## Strategic Take

Colossus (or any similar player) is primarily a **distribution and acquirer-relationship company** wearing a crypto L2 hat. The tech is table stakes; the moat is getting merchants' existing payment processors to recognize the new scheme.

For Subscriptor / Cardano, the realistic path is not "Colossus adopts Cardano tomorrow." It is:

- Build the cleanest possible recurring-pull + script-account + recovery story on Cardano.
- Position it as the best-in-class settlement layer for anyone who wants to issue cards (or card-like instruments) that settle on-chain.
- Be ready with a minimal integration surface (probably a combination of Subscriptor validators + a standardized "collector" script interface) so that when a Colossus-like player decides they want a non-Ethereum option, the integration is obvious and low-friction.

The Bullet + Subscriptor integration work is actually highly relevant here. A unified account abstraction story that includes native recurring pull payments (both the pure-crypto Mode 1 and the open-ended card-connected Mode 2) is exactly the kind of capability that would make Cardano attractive as a card settlement rail. The two-mode model we clarified above makes the integration even more valuable: Bullet provides the flexible policy layer for both decentralized subscriptions and card-authorized open pulls, while Subscriptor remains the clean state machine for billing history and constraints.

We should continue refining the Subscriptor + Bullet vision while keeping an eye on early acquirer-facing crypto card projects. The first one that successfully adds a second chain will have done the hard distribution work for everyone else.

---

## Sources

**Primary Reporting**
- Decrypt article: "Inside the Quest at Colossus to Replace Visa and Mastercard With KYC-Less Crypto Cards" (March 2026)  
  https://decrypt.co/360147/inside-quest-colossus-replace-visa-mastercard-kyc-less-crypto-cards  
  — Main source for founder quotes, funding details, technical architecture, settlement model, and GENIUS Act positioning.

**Founders Profile**
- Founders, Inc. portfolio page for Colossus  
  https://f.inc/portfolio/colossus/  
  — Confirms founder background (Joseph Delong, ex-SushiSwap CTO, Teku contributor) and high-level product description.

**Direct Observation**
- Colossus website (colossus.credit) — minimal placeholder as of May 2026.

**Cardano Context**
- Public CIP repository and dcSpark announcements regarding CIP-0038 (account abstraction) — used for the hard-fork assessment.
- Our ongoing Subscriptor and Bullet work (internal).

**General Knowledge**
- Card routing mechanics (BIN, AID, EMVCo) are standard industry practices documented across Visa, Mastercard, and EMVCo specifications.

---

**Next steps to consider:**
- Draft a minimal "Collector Interface" specification for Subscriptor that an external card network could implement against.
- Explore whether any existing Cardano projects are already talking to acquirers or EMV vendors.
- Monitor Colossus (and competitors) for any public developer program or chain-agnostic announcements.