# Subscriptor

Smart contract wallet supporting pull-based subscriptions on Cardano.

## Overview

Subscriptor enables recurring payments on Cardano through a smart contract "account" model. Owners deposit funds into a script address and mint subscription NFTs that authorize merchants to collect payments on a defined schedule.

### Key features

- **Deposit & withdraw** — owners can freely send tokens to the script address and withdraw non-subscription UTXOs at any time.
- **Subscription minting** — CIP-68 reference NFTs encode billing details (amount, currency, schedule, merchant) as inline datums.
- **Pull-based collection** — merchants (or anyone on their behalf) can collect the billable amount once per billing period, without the owner being online.
- **Billing schedules** — daily, weekly, bi-weekly, monthly, or arbitrary millisecond intervals.
- **Cancellation** — the owner can burn the subscription NFT at any time to cancel.
- **Platform fees** — an on-chain fee schedule (also a CIP-68 reference datum) defines the platform's cut; zero-fee is supported.

## Project structure

```
validators/       Aiken on-chain validators (subscriptor.ak, date.ak)
offchain/         Lucid-based transaction builders (mint, collect, deploy, query)
scripts/          Shell & JS helpers for wallet setup, parameterization, and testing
```

## Building

Requires [Aiken](https://aiken-lang.org/) v1.1.21+.

```bash
aiken build
aiken check   # compile + run tests
```

## License

[Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0)
