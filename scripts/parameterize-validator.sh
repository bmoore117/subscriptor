#!/bin/bash

cp ../plutus.json .

node param-application.js "oneshot.handle_subscription" $(cardano-cli address key-hash --payment-verification-key-file my_address.vkey)