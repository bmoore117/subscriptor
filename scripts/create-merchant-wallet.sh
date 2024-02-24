#!/bin/bash

cardano-cli address key-gen --verification-key-file merchant.vkey --signing-key-file merchant.skey

cardano-cli address build --payment-verification-key-file merchant.vkey --out-file merchant.addr --testnet-magic $CARDANO_NODE_MAGIC