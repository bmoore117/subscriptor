#!/bin/bash

cardano-cli query utxo --address $(cat intermediate/merchant.addr) --testnet-magic $CARDANO_NODE_MAGIC