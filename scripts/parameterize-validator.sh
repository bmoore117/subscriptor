#!/bin/bash

cp ../plutus.json .

node param-application.js "subscriptor.handle_subscription" $(cardano-cli address key-hash --payment-verification-key-file intermediate/user.vkey) $(cat intermediate/platform-policy.id)