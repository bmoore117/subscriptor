#!/bin/bash

cardano-cli transaction build --babbage-era \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --change-address $(cat my_address.addr) \
 --tx-in "151ecca5d87609d2414e33b98ed9f0cda3a1fcc89ba7a4152738db6db4713dff#0" \
 --tx-out "$(cat $1.addr) 5000000 lovelace" \
 --tx-out-reference-script-file $1.plutus \
 --tx-out-datum-hash-file unit.json \
 --out-file raw.tx

cardano-cli transaction sign \
 --tx-body-file ./raw.tx \
 --signing-key-file ./my_address.skey \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --out-file signed.tx

cardano-cli transaction submit \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-file ./signed.tx