#!/bin/bash

cardano-cli query utxo --address $(cat subscriptor.subscriptor.spend.addr) --testnet-magic ${CARDANO_NODE_MAGIC}