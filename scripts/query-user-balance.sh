#!/bin/bash

cardano-cli query utxo --address $(cat intermediate/user.addr) --testnet-magic $CARDANO_NODE_MAGIC