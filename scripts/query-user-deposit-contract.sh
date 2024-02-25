#!/bin/bash

cardano-cli query utxo --address $(cat subscriptor.handle_subscription.addr) --testnet-magic ${CARDANO_NODE_MAGIC}