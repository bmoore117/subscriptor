#!/bin/bash

cd ..
aiken build -t verbose
mv plutus.json scripts
cd scripts
node param-application.js "subscriptor.handle_subscription" $(cardano-cli address key-hash --payment-verification-key-file intermediate/user.vkey) $(cat intermediate/platform-policy.id)