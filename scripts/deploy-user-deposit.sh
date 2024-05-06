#!/bin/bash

output=$(cardano-cli transaction calculate-min-required-utxo \
 --protocol-params-file intermediate/params.json \
 --tx-out-reference-script-file subscriptor.handle_subscription.plutus \
 --tx-out-datum-hash-file unit.json \
 --tx-out "$(cat subscriptor.handle_subscription.addr) + 10000 lovelace") 

datacost=$(cut -d' ' -f2 <<< "$output")

output=$(./query-user-balance.sh)
txhash=$(echo $output | cut -d ' ' -f5)
txix=$(echo $output | cut -d ' ' -f6)

cardano-cli transaction build \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --change-address $(cat intermediate/user.addr) \
 --tx-in $txhash#$txix \
 --tx-out "$(cat subscriptor.handle_subscription.addr) $datacost lovelace" \
 --tx-out-reference-script-file subscriptor.handle_subscription.plutus \
 --tx-out-datum-hash-file unit.json \
 --out-file intermediate/user-deploy-raw.tx

cardano-cli transaction sign \
 --tx-body-file intermediate/user-deploy-raw.tx \
 --signing-key-file intermediate/user.skey \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --out-file intermediate/user-deploy-signed.tx

cardano-cli transaction submit \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-file intermediate/user-deploy-signed.tx