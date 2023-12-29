#!/bin/bash

cardano-cli query utxo --address $(cat $1.addr) --testnet-magic ${CARDANO_NODE_MAGIC}