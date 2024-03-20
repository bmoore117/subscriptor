#!/bin/bash

echo -n "Please enter a subscription name: "
read tokenname

tokenname=$(echo -n "$tokenname" | xxd -ps | tr -d '\n')
tokenname="000643b0$tokenname"
echo "Token name encoded: $tokenname"

json_data=$(cat intermediate/subscription-metadata.json)

output=$(cardano-cli transaction calculate-min-required-utxo \
 --protocol-params-file intermediate/params.json \
 --tx-out-inline-datum-file intermediate/subscription-metadata.json \
 --tx-out $(cat subscriptor.handle_subscription.addr)+0+"1 $(cat subscriptor.handle_subscription.pol).$tokenname")

datacost=$(cut -d' ' -f2 <<< "$output")

output=$(./query-user-balance.sh)
txhash=$(echo $output | cut -d ' ' -f5)
txix=$(echo $output | cut -d ' ' -f6)

output=$(./query-user-deposit-contract.sh)
minter_script_tx_hash=$(echo $output | cut -d ' ' -f5)
minter_script_tx_ix=$(echo $output | cut -d ' ' -f6)

lower_slot=$(cardano-cli query slot-number $(date -u +"%Y-%m-%dT%H:%M:%SZ") --testnet-magic $CARDANO_NODE_MAGIC)
upper_seconds=$(date +%s -d "+3 minute")
upper_date=$(date --date="@$upper_seconds" +"%Y-%m-%dT%H:%M:%SZ")
upper_slot=$(cardano-cli query slot-number $upper_date --testnet-magic $CARDANO_NODE_MAGIC)

node create-subscription-datum.js $upper_seconds

#tx-in and mint-tx-in should be the same? use the user's money in the contract?
cardano-cli transaction build --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-in $txhash#$txix \
 --tx-in-collateral $txhash#$txix \
 --mint-tx-in-reference $minter_script_tx_hash#$minter_script_tx_ix \
 --mint-plutus-script-v2 \
 --mint-reference-tx-in-redeemer-file unit.json \
 --policy-id $(cat subscriptor.handle_subscription.pol) \
 --mint "1 $(cat subscriptor.handle_subscription.pol).$tokenname" \
 --tx-out $(cat subscriptor.handle_subscription.addr)+$datacost+"1 $(cat subscriptor.handle_subscription.pol).$tokenname" \
 --tx-out-inline-datum-file intermediate/subscription-metadata.json \
 --required-signer-hash $(cardano-cli address key-hash --payment-verification-key-file intermediate/user.vkey) \
 --invalid-before $lower_slot \
 --invalid-hereafter $upper_slot \
 --change-address $(cat intermediate/user.addr) \
 --out-file intermediate/mint-raw.tx

cardano-cli transaction sign \
 --tx-body-file intermediate/mint-raw.tx \
 --signing-key-file intermediate/user.skey \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --out-file intermediate/mint-signed.tx

# for some reason, cardano-cli query slot-number above will give future slots, even for the current time. 
# Just sleep a bit to get in range
 sleep 25

cardano-cli transaction submit \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-file intermediate/mint-signed.tx