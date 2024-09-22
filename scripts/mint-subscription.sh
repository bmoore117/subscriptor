#!/bin/bash

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

# for some reason, cardano-cli query slot-number above will give future slots, even for the current time. 
# so back up two minutes
lower_seconds=$(date +%s -d "-120 seconds")
lower_date=$(date --date="@$lower_seconds" +"%Y-%m-%dT%H:%M:%SZ")
lower_slot=$(cardano-cli conway query slot-number $lower_date --testnet-magic $CARDANO_NODE_MAGIC)

upper_seconds=$(date +%s -d "+1 minute")
upper_date=$(date --date="@$upper_seconds" +"%Y-%m-%dT%H:%M:%SZ")
upper_slot=$(cardano-cli conway query slot-number $upper_date --testnet-magic $CARDANO_NODE_MAGIC)

key_hash=$(cardano-cli conway address key-hash --payment-verification-key-file intermediate/merchant.vkey)
node create-subscription-datum.js $upper_seconds $key_hash

output=$(cardano-cli conway transaction calculate-min-required-utxo \
 --protocol-params-file intermediate/params.json \
 --tx-out-inline-datum-file intermediate/subscription-metadata.json \
 --tx-out $(cat subscriptor.subscriptor.spend.addr)+0+"1 $(cat subscriptor.subscriptor.spend.pol).$tokenname")
datacost=$(cut -d' ' -f2 <<< "$output")

# this is the true minimum cost for the most minimal output you can have, 
# a UTXO going to a simple address with no ada in it, and no other data
# you can send any amount of ada above this, but no less than this per utxo
output=$(cardano-cli conway transaction calculate-min-required-utxo \
 --protocol-params-file intermediate/params.json \
 --tx-out "$(cat intermediate/platform.addr) + 0 lovelace")
min_cost_per_output=$(cut -d' ' -f2 <<< "$output")

# later we are going to have a transaction with 2 external outputs, 
# and move the original anchor token and datum, so our starting utxo needs enough ada to cover
total=$((2*datacost+2*min_cost_per_output))

output=$(./query-user-balance.sh)
user_tx_hash=$(echo $output | cut -d ' ' -f5)
user_tx_ix=$(echo $output | cut -d ' ' -f6)

output=$(./query-user-deposit-contract.sh)
minter_script_tx_hash=$(echo $output | cut -d ' ' -f5)
minter_script_tx_ix=$(echo $output | cut -d ' ' -f6)

#tx-in and mint-tx-in should be the same? use the user's money in the contract?
cardano-cli conway transaction build --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-in $user_tx_hash#$user_tx_ix \
 --tx-in-collateral $user_tx_hash#$user_tx_ix \
 --mint-tx-in-reference $minter_script_tx_hash#$minter_script_tx_ix \
 --mint-plutus-script-v3 \
 --mint-reference-tx-in-redeemer-file unit.json \
 --policy-id $(cat subscriptor.subscriptor.spend.pol) \
 --mint "1 $(cat subscriptor.subscriptor.spend.pol).$tokenname" \
 --tx-out $(cat subscriptor.subscriptor.spend.addr)+$total+"1 $(cat subscriptor.subscriptor.spend.pol).$tokenname" \
 --tx-out-inline-datum-file intermediate/subscription-metadata.json \
 --required-signer-hash $(cardano-cli conway address key-hash --payment-verification-key-file intermediate/user.vkey) \
 --invalid-before $lower_slot \
 --invalid-hereafter $upper_slot \
 --change-address $(cat intermediate/user.addr) \
 --out-file intermediate/mint-raw.tx

cardano-cli conway transaction sign \
 --tx-body-file intermediate/mint-raw.tx \
 --signing-key-file intermediate/user.skey \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --out-file intermediate/mint-signed.tx

cardano-cli conway transaction submit \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-file intermediate/mint-signed.tx