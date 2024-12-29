if ($args.Count -eq 0) {
    $depositAmount = Read-Host "Enter deposit amount"
} else {
    $depositAmount = $args[0]
}

$key = Get-Content ..\scripts\intermediate\user.skey -Raw | ConvertFrom-Json | Select-Object cborHex
# remove leading 5820 as it is cbor header, then convert to bech32 (bech32.exe part of cardano-node installation along with cardano-cli)
$bech32 = $key.cborHex.Substring(4) | bech32 ed25519_sk

$platformAddr = (Get-Content ..\scripts\intermediate\platform.addr -Raw).Trim()
$platformPolicyId = (Get-Content ..\scripts\intermediate\platform-policy.id -Raw).Trim()

$scriptAddr = (Get-Content .\subscriptor.subscriptor.spend.addr -Raw).Trim()

npm run deploy -- $bech32 "1" $platformAddr $platformPolicyId $scriptAddr $depositAmount
