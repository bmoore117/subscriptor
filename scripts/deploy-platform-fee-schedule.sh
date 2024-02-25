#!/bin/bash

cat <<EOF > intermediate/platform-policy.script
{
    "type": "sig",
    "keyHash": "$(cardano-cli address key-hash --payment-verification-key-file intermediate/platform.vkey)"
}
EOF

cardano-cli transaction policyid --script-file intermediate/platform-policy.script > intermediate/platform-policy.id
output=$(cardano-cli query utxo --address $(cat intermediate/platform.addr) --testnet-magic $CARDANO_NODE_MAGIC)

address=$(cat intermediate/platform.addr)
txhash=$(echo $output | cut -d ' ' -f5)
txix=$(echo $output | cut -d ' ' -f6)
funds=$(echo $output | cut -d ' ' -f7)
policyid=$(cat intermediate/platform-policy.id)
#"PlatformFeeSchedule", prefixed with CIP-68 reference token identifier
tokenname="000643b0506c6174666f726d4665655363686564756c65"
mint="1 $policyid.$tokenname"

json_data=$(cat intermediate/platform-metadata.json)

output=$(cardano-cli transaction calculate-min-required-utxo \
 --protocol-params-file intermediate/params.json \
 --tx-out-inline-datum-value $json_data \
 --tx-out "$address+0+$mint")

datacost=$(cut -d' ' -f2 <<< "$output")

cardano-cli transaction build \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-in $txhash#$txix \
 --tx-out $address+$datacost+$mint \
 --change-address $address \
 --mint="1 $policyid.$tokenname" \
 --minting-script-file intermediate/platform-policy.script \
 --tx-out-inline-datum-value $json_data  \
 --out-file intermediate/platform-schedule-raw.tx

cardano-cli transaction sign \
 --tx-body-file intermediate/platform-schedule-raw.tx \
 --signing-key-file ./platform.skey \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --out-file intermediate/platform-schedule-signed.tx

cardano-cli transaction submit \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-file intermediate/platform-schedule-signed.tx


