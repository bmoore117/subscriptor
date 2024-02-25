#!/bin/bash

cardano-cli query utxo --address $(cat intermediate/platform.addr) --testnet-magic $CARDANO_NODE_MAGIC