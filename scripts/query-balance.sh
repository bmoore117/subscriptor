#!/bin/bash

cardano-cli query utxo --address $(cat my_address.addr) --testnet-magic $CARDANO_NODE_MAGIC