#!/bin/bash

cardano-cli address key-gen --verification-key-file platform.vkey --signing-key-file platform.skey

cardano-cli address build --payment-verification-key-file platform.vkey --out-file platform.addr --testnet-magic $CARDANO_NODE_MAGIC

echo "Don't forget to fund your newly created wallet, then run deploy-platform-fee-schedule.sh"