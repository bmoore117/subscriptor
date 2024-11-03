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

cardano-cli conway address build --payment-script-file subscriptor.subscriptor.spend.plutus --out-file subscriptor.subscriptor.spend.addr
$hash = Get-Content subscriptor.subscriptor.spend.addr -Raw | ..\scripts\bin\cardano-address.exe address inspect | ConvertFrom-Json | Select-Object spending_shared_hash
$hash.spending_shared_hash | Out-File .\subscriptor.subscriptor.spend.pol -Encoding ascii
