param(
    [string]$Profile = $env:AWS_PROFILE,
    [string]$Region = "eu-north-1",
    [switch]$DestroyAfterTest,
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"

Write-Host "STEP 1/3 - Validate Terraform" -ForegroundColor Cyan
& "$PSScriptRoot/validate.ps1" -Profile $Profile -Region $Region

Write-Host "STEP 2/3 - Deploy infrastructure" -ForegroundColor Cyan
if ($AutoApprove) {
    & "$PSScriptRoot/deploy.ps1" -Profile $Profile -Region $Region -AutoApprove
}
else {
    & "$PSScriptRoot/deploy.ps1" -Profile $Profile -Region $Region
}

Write-Host "STEP 3/3 - Run functional tests" -ForegroundColor Cyan
& "$PSScriptRoot/test.ps1" -Profile $Profile -Region $Region

Write-Host "End-to-end validation completed successfully." -ForegroundColor Green

if ($DestroyAfterTest) {
    Write-Host "Cleanup requested - destroying Terraform-managed resources." -ForegroundColor Cyan
    if ($AutoApprove) {
        & "$PSScriptRoot/destroy.ps1" -Profile $Profile -Region $Region -AutoApprove
    }
    else {
        & "$PSScriptRoot/destroy.ps1" -Profile $Profile -Region $Region
    }
}
else {
    Write-Host "Infrastructure is still running. Use .\scripts\destroy.ps1 after collecting evidence." -ForegroundColor Yellow
}
