#!/bin/bash

cardano-cli query protocol-parameters --testnet-magic ${CARDANO_NODE_MAGIC} > params.json