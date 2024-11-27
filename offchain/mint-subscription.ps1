$tokenName = $null
if ($args.Count -eq 0) {
    $tokenName = Read-Host "Please enter a subscription name"
} else {
    $tokenName = $args[0]
}

$key = Get-Content ..\scripts\intermediate\user.skey -Raw | ConvertFrom-Json | Select-Object cborHex
# remove leading 5820 as it is cbor header, then convert to bech32 (bech32.exe part of cardano-node installation along with cardano-cli)
$bech32 = $key.cborHex.Substring(4) | bech32 ed25519_sk

$policy = (Get-Content .\subscriptor.subscriptor.spend.pol -Raw).Trim()
$scriptAddr = (Get-Content .\subscriptor.subscriptor.spend.addr -Raw).Trim()

$merchantVkey = cardano-cli conway address key-hash --payment-verification-key-file ..\scripts\intermediate\merchant.vkey
$userVkey = (Get-Content ..\scripts\intermediate\user.addr -Raw).Trim()

npm run mint $merchantVkey $bech32 $policy $tokenName $scriptAddr $userVkey