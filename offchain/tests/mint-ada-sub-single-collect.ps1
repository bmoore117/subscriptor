$path = Get-Location
if ($path.Path.EndsWith("offchain")) {
    .\mint-subscription.ps1 -SubscriptionName TestSub -DepositAmount 3396280 -BillableAmount 849070 -TokenPolicy ada -TokenName ada
} else {
    .\mint-subscription.ps1 -SubscriptionName TestSub -DepositAmount 3396280 -BillableAmount 849070 -TokenPolicy ada -TokenName ada
}

Write-Host "After deployment complete, collect with .\collect.ps1 TestSub"