#!/bin/bash

cardano-cli address key-gen --verification-key-file intermediate/user.vkey --signing-key-file intermediate/user.skey

cardano-cli address build --payment-verification-key-file intermediate/user.vkey --out-file intermediate/user.addr --testnet-magic $CARDANO_NODE_MAGIC