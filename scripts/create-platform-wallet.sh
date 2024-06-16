#!/bin/bash

cardano-cli address key-gen --verification-key-file intermediate/platform.vkey --signing-key-file intermediate/platform.skey

cardano-cli address build --payment-verification-key-file intermediate/platform.vkey --out-file intermediate/platform.addr --testnet-magic $CARDANO_NODE_MAGIC

echo "Don't forget to fund your newly created wallet, then run mint-platform-fee-schedule.sh"