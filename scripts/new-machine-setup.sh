#!/bin/bash

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.profile
nvm install 18
nvm use 18

npm install -g @aiken-lang/aikup
aikup
echo 'export PATH=$PATH:/config/.aiken/bin' >> ~/.bashrc
source ~/.bashrc