#!/bin/bash

cardano-cli address key-gen --verification-key-file my_address.vkey --signing-key-file my_address.skey

cardano-cli address build --payment-verification-key-file my_address.vkey --out-file my_address.addr --testnet-magic $CARDANO_NODE_MAGIC