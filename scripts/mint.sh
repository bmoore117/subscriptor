#!/bin/bash

tokenname=$(echo -n "$4" | xxd -ps | tr -d '\n')
tokenname="000643b0$tokenname"
echo "Token name encoded: $tokenname"

output=$(cardano-cli transaction calculate-min-required-utxo \
 --protocol-params-file params.json \
 --tx-out $(cat $3.addr)+0+"1 $(cat $3.pol).$tokenname")

datacost=$(cut -d' ' -f2 <<< "$output")

cardano-cli transaction build --testnet-magic ${CARDANO_NODE_MAGIC} \
 --tx-in $1 \
 --tx-in-collateral $1 \
 --mint-tx-in-reference $2 \
 --mint-plutus-script-v2 \
 --mint-reference-tx-in-redeemer-file unit.json \
 --policy-id $(cat $3.pol) \
 --mint "1 $(cat $3.pol).$tokenname" \
 --tx-out $(cat $3.addr)+$datacost+"1 $(cat $3.pol).$tokenname" \
 --required-signer-hash $(cardano-cli address key-hash --payment-verification-key-file my_address.vkey) \
 --change-address $(cat $3.addr) \
 --out-file mint.tx

cardano-cli transaction sign \
 --tx-body-file ./mint.tx \
 --signing-key-file ./my_address.skey \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --out-file mint-signed.tx

cardano-cli transaction submit \
 --testnet-magic $CARDANO_NODE_MAGIC \
 --tx-file ./mint-signed.tx