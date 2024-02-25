#!/bin/bash

cardano-cli address key-gen --verification-key-file intermediate/merchant.vkey --signing-key-file intermediate/merchant.skey

cardano-cli address build --payment-verification-key-file intermediate/merchant.vkey --out-file intermediate/merchant.addr --testnet-magic $CARDANO_NODE_MAGIC