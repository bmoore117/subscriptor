Set-Location ..

$subscriptor = Get-Content .\validators\subscriptor.ak -Raw
$null = $subscriptor -match 'Build #(\d+)'
$subscriptor -replace 'Build #(\d+)', ("Build #" + ([int]$matches[1] + 1)) | Out-File .\validators\subscriptor.ak -Encoding ascii
aiken build -t verbose
Move-Item .\plutus.json .\offchain -Force
Set-Location .\offchain

$userKey = cardano-cli address key-hash --payment-verification-key-file ..\scripts\intermediate\user.vkey
$platformPolicyId = Get-Content ..\scripts\intermediate\platform-policy.id -Raw

npm run parameterize -- "subscriptor.subscriptor.spend" $userKey $platformPolicyId

$key = Get-Content ..\scripts\intermediate\user.skey -Raw | ConvertFrom-Json | Select-Object cborHex
# remove leading 5820 as it is cbor header, then convert to bech32 (bech32.exe part of cardano-node installation along with cardano-cli)
$bech32 = $key.cborHex.Substring(4) | bech32 ed25519_sk

$scriptAddr = cardano-cli conway address build --payment-script-file subscriptor.subscriptor.spend.json
$scriptAddr | Out-File .\subscriptor.subscriptor.spend.addr -Encoding ascii

# make policy for completeness' sake
$hash = Get-Content subscriptor.subscriptor.spend.addr -Raw | ..\scripts\bin\cardano-address.exe address inspect | ConvertFrom-Json | Select-Object spending_shared_hash
$hash.spending_shared_hash | Out-File .\subscriptor.subscriptor.spend.pol -Encoding ascii

npm run deploy -- $bech32 $scriptAddr
