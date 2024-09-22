#!/bin/bash

output=$(cardano-cli conway transaction calculate-min-required-utxo \
 --protocol-params-file intermediate/params.json \
 --tx-out-reference-script-file subscriptor.subscriptor.spend.plutus \
 --tx-out-datum-hash-file unit.json \
 --tx-out "$(cat subscriptor.subscriptor.spend.addr) + 0") 

datacost=$(cut -d' ' -f2 <<< "$output")

output=$(./query-user-balance.sh)
txhash=$(echo $output | cut -d ' ' -f5)
txix=$(echo $output | cut -d ' ' -f6)

cardano-cli conway transaction build \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --change-address $(cat intermediate/user.addr) \
 --tx-in $txhash#$txix \
 --tx-out "$(cat subscriptor.subscriptor.spend.addr) $datacost lovelace" \
 --tx-out-reference-script-file subscriptor.subscriptor.spend.plutus \
 --tx-out-datum-hash-file unit.json \
 --out-file intermediate/user-deploy-raw.tx

cardano-cli conway transaction sign \
 --tx-body-file intermediate/user-deploy-raw.tx \
 --signing-key-file intermediate/user.skey \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --out-file intermediate/user-deploy-signed.tx

cardano-cli conway transaction submit \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-file intermediate/user-deploy-signed.tx