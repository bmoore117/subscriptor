#!/bin/bash

cd ..
build_number=$(grep "Build #" validators/subscriptor.ak | head -1 | grep -Po '[0-9]+')
build_number=$((build_number + 1))
sed -r -i "s/(Build \#)([0-9]+)/\1$build_number/" validators/subscriptor.ak
aiken build -t verbose
mv plutus.json scripts
cd scripts
node param-application.js "subscriptor.subscriptor.spend" $(cardano-cli address key-hash --payment-verification-key-file intermediate/user.vkey) $(cat intermediate/platform-policy.id)
cardano-cli conway address build --payment-script-file subscriptor.subscriptor.spend.plutus --out-file subscriptor.subscriptor.spend.addr
cat subscriptor.subscriptor.spend.addr | bin/cardano-address address inspect | jq -r '.spending_shared_hash' > subscriptor.subscriptor.spend.pol
