#!/bin/bash

output=$(./query-platform-balance.sh)
txhash=$(echo "$output" | grep -w TxOutDatumInline | cut -d ' ' -f1)
txix=$(echo "$output" | grep -w TxOutDatumInline | tr -s ' ' | cut -d ' ' -f2)

# find largest utxo, sure to cover needs
extratxhash=$(echo "$output" | grep -w TxOutDatumNone | sort -r | head -n 1 | cut -d ' ' -f1)
extratxix=$(echo "$output" | grep -w TxOutDatumNone | sort -r | head -n 1 | tr -s ' ' | cut -d ' ' -f2)

address=$(cat intermediate/platform.addr)
policyid=$(cat intermediate/platform-policy.id)
#"PlatformFeeSchedule", prefixed with CIP-68 reference token identifier
tokenname="000643b0506c6174666f726d4665655363686564756c65"
mint="-1 $policyid.$tokenname"
concat="$txhash#$txix"

output=$(cardano-cli transaction build \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-in $concat \
 --tx-out $address+0 \
 --mint="-1 $policyid.$tokenname" \
 --minting-script-file intermediate/platform-policy.script \
 --change-address $address \
 --out-file intermediate/burning-fee-schedule-raw.tx 2>&1 >/dev/null)

cost=$(echo "$output" | rev | cut -d ' ' -f1 | rev | xargs echo -n)

cardano-cli transaction build \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-in $txhash#$txix \
 --tx-in $extratxhash#$extratxix \
 --tx-out $address+$cost \
 --mint="-1 $policyid.$tokenname" \
 --minting-script-file intermediate/platform-policy.script \
 --change-address $address \
 --out-file intermediate/burning-fee-schedule-raw.tx

cardano-cli transaction sign \
 --tx-body-file intermediate/burning-fee-schedule-raw.tx \
 --signing-key-file intermediate/platform.skey \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --out-file intermediate/burning-fee-schedule-signed.tx

cardano-cli transaction submit \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-file intermediate/burning-fee-schedule-signed.tx


