#!/bin/bash

output=$(cardano-cli transaction calculate-min-required-utxo \
 --protocol-params-file intermediate/params.json \
 --tx-out-inline-datum-file intermediate/subscription-metadata-updated.json \
 --tx-out $(cat subscriptor.handle_subscription.addr)+0+"1 $(cat subscriptor.handle_subscription.pol).$tokenname")
anchor_cost=$(cut -d' ' -f2 <<< "$output")

# this is the true minimum cost for the most minimal output you can have, 
# a UTXO going to a simple address with no ada in it, and no other data
# you can send any amount of ada above this, but no less than this per utxo
output=$(cardano-cli transaction calculate-min-required-utxo \
 --protocol-params-file intermediate/params.json \
 --tx-out "$(cat intermediate/platform.addr) + 0 lovelace")
min_cost_per_output=$(cut -d' ' -f2 <<< "$output")

output=$(cardano-cli transaction calculate-min-required-utxo \
 --protocol-params-file intermediate/params.json \
 --tx-out-datum-hash-file unit.json \
 --tx-out "$(cat subscriptor.handle_subscription.addr) + 0 lovelace")
cost_for_new_utxo=$(cut -d' ' -f2 <<< "$output")

# later we are going to have a transaction with 2 external outputs, 
# and move the original anchor token and datum, so our starting utxo needs enough ada to cover
total=$((2*anchor_cost+2*min_cost_per_output+cost_for_new_utxo))

output=$(./query-user-balance.sh)
txhash=$(echo $output | cut -d ' ' -f5)
txix=$(echo $output | cut -d ' ' -f6)

cardano-cli transaction build \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --change-address $(cat intermediate/user.addr) \
 --tx-in $txhash#$txix \
 --tx-out "$(cat subscriptor.handle_subscription.addr) $total lovelace" \
 --tx-out-datum-hash-file unit.json \
 --out-file intermediate/user-deploy-additional-raw.tx

cardano-cli transaction sign \
 --tx-body-file intermediate/user-deploy-additional-raw.tx \
 --signing-key-file intermediate/user.skey \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --out-file intermediate/user-deploy-additional-signed.tx

cardano-cli transaction submit \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-file intermediate/user-deploy-additional-signed.tx