#!/bin/bash

echo -n "Please enter a platform fee amount in basis points: "
read feeamount

key_hash=$(cardano-cli address key-hash --payment-verification-key-file intermediate/platform.vkey)

cat <<EOF > intermediate/platform-policy.script
{
    "type": "sig",
    "keyHash": "$key_hash"
}
EOF

cardano-cli transaction policyid --script-file intermediate/platform-policy.script > intermediate/platform-policy.id
output=$(./query-platform-balance.sh | grep TxOutDatumNone | rev | sort -r | rev | head -n 1) # find largest utxo, sure to cover needs

address=$(cat intermediate/platform.addr)
txhash=$(echo "$output" | cut -d ' ' -f1)
txix=$(echo "$output" | tr -s ' ' | cut -d ' ' -f2)
policyid=$(cat intermediate/platform-policy.id)
#"PlatformFeeSchedule", prefixed with CIP-68 reference token identifier
tokenname="000643b0506c6174666f726d4665655363686564756c65"
mint="1 $policyid.$tokenname"

# this is the true minimum cost for the most minimal output you can have, 
# a UTXO going to a simple address with no ada in it, and no other data
# you can send any amount of ada above this, but no less than this per utxo
output=$(cardano-cli transaction calculate-min-required-utxo \
 --protocol-params-file intermediate/params.json \
 --tx-out "$(cat intermediate/platform.addr) + 0 lovelace")
min_cost_per_output=$(cut -d' ' -f2 <<< "$output")

node create-fee-schedule-datum.js $feeamount $key_hash $min_cost_per_output

output=$(cardano-cli transaction calculate-min-required-utxo \
 --protocol-params-file intermediate/params.json \
 --tx-out-inline-datum-cbor-file intermediate/platform-metadata.cbor \
 --tx-out "$address+0+$mint")

datacost=$(cut -d' ' -f2 <<< "$output")

cardano-cli conway transaction build \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-in $txhash#$txix \
 --tx-out $address+$datacost+"$mint" \
 --change-address $address \
 --mint="1 $policyid.$tokenname" \
 --minting-script-file intermediate/platform-policy.script \
 --tx-out-inline-datum-cbor-file intermediate/platform-metadata.cbor  \
 --out-file intermediate/platform-schedule-raw.tx

cardano-cli transaction sign \
 --tx-body-file intermediate/platform-schedule-raw.tx \
 --signing-key-file intermediate/platform.skey \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --out-file intermediate/platform-schedule-signed.tx

cardano-cli transaction submit \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-file intermediate/platform-schedule-signed.tx


