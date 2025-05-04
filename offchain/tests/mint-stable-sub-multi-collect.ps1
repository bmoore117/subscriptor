$path = Get-Location
if ($path.Path.EndsWith("offchain")) {
    .\mint-subscription.ps1 -SubscriptionName TestStableSub -DepositAmount 400 -BillableAmount 200 -TokenPolicy e81c012dbae68ee9e8b2443faf3bce1dd52ead70f7e06cbab00eceb6 -TokenName ImaginaryStablecoin
} else {
    ..\mint-subscription.ps1 -SubscriptionName TestStableSub -DepositAmount 400 -BillableAmount 200 -TokenPolicy e81c012dbae68ee9e8b2443faf3bce1dd52ead70f7e06cbab00eceb6 -TokenName ImaginaryStablecoin
}

Write-Host "Requires deployment of additional funds to cover ADA min utxo amounts, suggested invocation: .\deploy-additional-funds.ps1 3396280"
Write-Host "After deployment complete, collect with .\collect.ps1 TestStableSub"