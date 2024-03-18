#!/bin/bash

# need: redeemer, multiple inputs including the right datum, and a reference input of the platform
# also need: to generate proper output datum

echo -n "Please enter a subscription name: "
read tokenname

tokenname=$(echo -n "$tokenname" | xxd -ps | tr -d '\n')
tokenname="000643b0$tokenname"
echo "Token name encoded: $tokenname"

json_data=$(cat collect-payment-redeemer.json)

# generate the new datum, and return the value to collect, all in one
billable_amount=$(node generate-updated-subscription-datum.js)

output=$(cardano-cli transaction calculate-min-required-utxo \
 --protocol-params-file intermediate/params.json \
 --tx-out-inline-datum-file intermediate/subscription-metadata-updated.json \
 --tx-out $(cat merchant.addr)+$billable_amount \
 --tx-out "1 $(cat subscriptor.handle_subscription.pol).$tokenname")

datacost=$(cut -d' ' -f2 <<< "$output")

output=$(./query-user-deposit-contract.sh)
datum_txhash=$(echo "$output" | grep -w $tokenname | cut -d ' ' -f1)
datum_txix=$(echo "$output" | grep -w $tokenname | cut -d ' ' -f2)
script_txhash=$(echo "$output" | grep -w $tokenname | cut -d ' ' -f1)
script_txix=$(echo "$output" | grep -w $tokenname | cut -d ' ' -f2)

output=$(./query-platform-balance.sh)
platform_txhash=$(echo "$output" | grep -w ScriptDataInBabbageEra | cut -d ' ' -f1)
platform_txix=$(echo "$output" | grep -w ScriptDataInBabbageEra | cut -d ' ' -f2)

output=$(./query-merchant-balance.sh)
merchant_txhash=$(echo "$output" | grep -w TxOutDatumNone | cut -d ' ' -f1)
merchant_txix=$(echo "$output" | grep -w TxOutDatumNone | cut -d ' ' -f2)

cardano-cli transaction build --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-in $datum_txhash#$datum_txix \
 --tx-in-collateral $merchant_txhash#$merchant_txix \
 --spending-tx-in-reference $script_txhash#$script_txix \
 --spending-plutus-script-v2 \
 --spending-reference-tx-in-redeemer-file collect-payment-redeemer.json \
 --tx-out $(cat merchant.addr)+$billable_amount \
 --tx-out "1 $(cat subscriptor.handle_subscription.pol).$tokenname" \
 --tx-out-inline-datum-file intermediate/subscription-metadata-updated.json \
 --required-signer-hash $(cardano-cli address key-hash --payment-verification-key-file intermediate/merchant.vkey) \
 --change-address $(cat intermediate/subscriptor.handle_subscription.addr) \
 --out-file intermediate/collect-raw.tx

cardano-cli transaction sign \
 --tx-body-file intermediate/collect-raw.tx \
 --signing-key-file intermediate/merchant.skey \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --out-file intermediate/collect-signed.tx

cardano-cli transaction submit \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-file intermediate/collect-signed.tx