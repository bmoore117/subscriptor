#!/bin/bash

cd ..
aiken build -t verbose
mv plutus.json scripts
cd scripts
node param-application.js "subscriptor.subscriptor.spend" $(cardano-cli address key-hash --payment-verification-key-file intermediate/user.vkey) $(cat intermediate/platform-policy.id)
cardano-cli conway address build --payment-script-file subscriptor.subscriptor.spend.plutus --out-file subscriptor.subscriptor.spend.addr
