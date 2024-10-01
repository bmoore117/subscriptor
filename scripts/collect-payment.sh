#!/bin/bash

# need: redeemer, multiple inputs including the right datum, and a reference input of the platform
# also need: to generate proper output datum

if [ -z "$1" ]
  then
    echo -n "Please enter a subscription name: "
    read tokenname
  else
    tokenname=$1
fi

tokenname=$(echo -n "$tokenname" | xxd -ps | tr -d '\n')
tokenname="000643b0$tokenname"
echo "Token name encoded: $tokenname"

# generate the new datum, and return the value to collect, all in one
billable_amount=$(node generate-updated-subscription-datum.js)

output=$(./query-user-deposit-contract.sh)
datum_txhash=$(echo "$output" | grep -w $tokenname | cut -d ' ' -f1)
datum_txix=$(echo "$output" | grep -w $tokenname | tr -s ' ' | cut -d ' ' -f2)
datum_lovelace=$(echo "$output" | grep -w $tokenname | tr -s ' ' | cut -d ' ' -f3)
script_txhash=$(echo "$output" | grep -w AlonzoEraOnwardsConway | head -n 1 | cut -d ' ' -f1)
script_txix=$(echo "$output" | grep -w AlonzoEraOnwardsConway | head -n 1 | tr -s ' ' | cut -d ' ' -f2)

echo $script_txhash
echo $script_txix

output=$(./query-platform-balance.sh)
platform_txhash=$(echo "$output" | grep -w TxOutDatumInline | cut -d ' ' -f1)
platform_txix=$(echo "$output" | grep -w TxOutDatumInline | tr -s ' ' | cut -d ' ' -f2)

# need single tx details, so find largest tx
output=$(./query-merchant-balance.sh)
merchant_txhash=$(echo "$output" | grep -w TxOutDatumNone | tr -s ' ' | sort -nrk3,3 | head -n 1 | cut -d ' ' -f1)
merchant_txix=$(echo "$output" | grep -w TxOutDatumNone | tr -s ' ' | sort -nrk3,3 | head -n 1 | cut -d ' ' -f2)

platform_fee=$(node calculate-platform-tx-fee.js)

output=$(cardano-cli conway transaction calculate-min-required-utxo \
 --protocol-params-file intermediate/params.json \
 --tx-out $(cat subscriptor.subscriptor.spend.addr)+0+"1 $(cat subscriptor.subscriptor.spend.pol).$tokenname" \
 --tx-out-inline-datum-file intermediate/subscription-metadata-updated.json)
anchor_output_cost=$(cut -d' ' -f2 <<< "$output")

# this is the true minimum cost for the most minimal output you can have, 
# a UTXO going to a simple address with no ada in it, and no other data
# you can send any amount of ada above this, but no less than this per utxo
output=$(cardano-cli conway transaction calculate-min-required-utxo \
 --protocol-params-file intermediate/params.json \
 --tx-out "$(cat intermediate/platform.addr) + 0 lovelace")
min_cost_per_output=$(cut -d' ' -f2 <<< "$output")

if ((billable_amount < min_cost_per_output)); then
  billable_amount=$min_cost_per_output
fi

if ((platform_fee < min_cost_per_output)); then
  platform_fee=$min_cost_per_output
fi

output_total=$((billable_amount + platform_fee + anchor_output_cost))
input_remainder=$((datum_lovelace - output_total))

echo $output_total
echo $datum_lovelace

if (( output_total > datum_lovelace )); then
    echo "Using multi-utxo redemption"
    echo -n "Please enter additional tx hash: "
    read extra_tx
    echo -n "Please enter additional tx ix: "
    read extra_tx_ix

    # expectation is you give an additional tx with enough ada such that original tx + new tx have enough 
    # ada to cover the output total otherwise the tx will fail
    output=$(cardano-cli conway query utxo --tx-in $extra_tx#$extra_tx_ix --testnet-magic ${CARDANO_NODE_MAGIC})
    extra_datum_lovelace=$(echo "$output" | grep -w "lovelace" | tr -s ' ' | cut -d ' ' -f3)

    input_total=$((datum_lovelace + extra_datum_lovelace))
    input_remainder=$((input_total - output_total))

    cardano-cli conway transaction build --testnet-magic $CARDANO_NODE_MAGIC \
     --tx-in $datum_txhash#$datum_txix \
     --tx-in $extra_tx#$extra_tx_ix \
     --tx-in-collateral $merchant_txhash#$merchant_txix \
     --spending-tx-in-reference $script_txhash#$script_txix \
     --spending-plutus-script-v3 \
     --spending-reference-tx-in-redeemer-file collect-payment-redeemer.json \
     --tx-in-redeemer-file collect-payment-redeemer.json \
     --spending-reference-tx-in-datum-file unit.json \
     --read-only-tx-in-reference $platform_txhash#$platform_txix \
     --tx-out $(cat intermediate/merchant.addr)+$billable_amount \
     --tx-out $(cat intermediate/platform.addr)+$platform_fee \
     --tx-out $(cat subscriptor.subscriptor.spend.addr)+$input_remainder+"1 $(cat subscriptor.subscriptor.spend.pol).$tokenname" \
     --tx-out-inline-datum-file intermediate/subscription-metadata-updated.json \
     --required-signer-hash $(cardano-cli address key-hash --payment-verification-key-file intermediate/merchant.vkey) \
     --change-address $(cat subscriptor.subscriptor.spend.addr) \
     --out-file intermediate/collect-raw-multi-utxo.tx

    if [ $? -eq 1 ]; then
      exit 1
    fi

    cardano-cli transaction sign \
     --tx-body-file intermediate/collect-raw-multi-utxo.tx \
     --signing-key-file intermediate/merchant.skey \
     --testnet-magic $CARDANO_NODE_MAGIC \
     --out-file intermediate/collect-signed-multi-utxo.tx
     
    cardano-cli transaction submit \
    --testnet-magic $CARDANO_NODE_MAGIC \
    --tx-file intermediate/collect-signed-multi-utxo.tx
else
    cardano-cli conway transaction build --testnet-magic $CARDANO_NODE_MAGIC \
     --tx-in $datum_txhash#$datum_txix \
     --tx-in-collateral $merchant_txhash#$merchant_txix \
     --spending-tx-in-reference $script_txhash#$script_txix \
     --spending-plutus-script-v3 \
     --spending-reference-tx-in-redeemer-file collect-payment-redeemer.json \
     --spending-reference-tx-in-datum-file unit.json \
     --read-only-tx-in-reference $platform_txhash#$platform_txix \
     --tx-out $(cat intermediate/merchant.addr)+$billable_amount \
     --tx-out $(cat intermediate/platform.addr)+$platform_fee \
     --tx-out $(cat subscriptor.subscriptor.spend.addr)+$input_remainder+"1 $(cat subscriptor.subscriptor.spend.pol).$tokenname" \
     --tx-out-inline-datum-file intermediate/subscription-metadata-updated.json \
     --required-signer-hash $(cardano-cli address key-hash --payment-verification-key-file intermediate/merchant.vkey) \
     --change-address $(cat intermediate/merchant.addr) \
     --out-file intermediate/collect-raw.tx

    if [ $? -eq 1 ]; then
      exit 1
    fi

    cardano-cli conway transaction sign \
     --tx-body-file intermediate/collect-raw.tx \
     --signing-key-file intermediate/merchant.skey \
     --testnet-magic $CARDANO_NODE_MAGIC \
     --out-file intermediate/collect-signed.tx
     
    cardano-cli conway transaction submit \
    --testnet-magic $CARDANO_NODE_MAGIC \
    --tx-file intermediate/collect-signed.tx
fi

if [ $? -eq 0 ]; then
  cp intermediate/subscription-metadata-updated.json intermediate/subscription-metadata.json
fi