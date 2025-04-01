$key = Get-Content ..\scripts\intermediate\user.skey -Raw | ConvertFrom-Json | Select-Object cborHex
# remove leading 5820 as it is cbor header, then convert to bech32 (bech32.exe part of cardano-node installation along with cardano-cli)
$userSkey = $key.cborHex.Substring(4) | bech32 ed25519_sk
$userVkey = cardano-cli conway address key-hash --payment-verification-key-file ..\scripts\intermediate\user.vkey

npm run mint-stables $userVkey $userSkey