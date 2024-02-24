#!/bin/bash

cardano-cli address key-gen --verification-key-file user.vkey --signing-key-file user.skey

cardano-cli address build --payment-verification-key-file user.vkey --out-file user.addr --testnet-magic $CARDANO_NODE_MAGIC