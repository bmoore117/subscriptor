#!/bin/bash

output=$(cardano-cli transaction calculate-min-required-utxo --babbage-era \
 --protocol-params-file params.json \
 --tx-out-reference-script-file $2.plutus \
 --tx-out "$(cat $2.addr) + 0")

datacost=$(cut -d' ' -f2 <<< "$output")

cardano-cli transaction build \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --change-address $(cat my_address.addr) \
 --tx-in $1 \
 --tx-out "$(cat $2.addr) $datacost lovelace" \
 --tx-out-reference-script-file $2.plutus \
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