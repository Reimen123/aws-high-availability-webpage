param(
    [string]$Profile = $env:AWS_PROFILE,
    [string]$Region = "eu-north-1"
)

. "$PSScriptRoot/common.ps1"

Set-AwsEnvironment -Profile $Profile -Region $Region
Assert-AwsAuthentication
Initialize-Terraform
Invoke-TerraformQualityChecks

$root = Get-ProjectRoot
Push-Location $root
try {
    Write-Host "Creating a Terraform execution plan..." -ForegroundColor Cyan
    terraform plan -input=false -out=tfplan
    if ($LASTEXITCODE -ne 0) { throw "terraform plan failed." }

    Remove-Item -Force tfplan -ErrorAction SilentlyContinue
    Write-Host "Validation successful: format, syntax, provider configuration and plan all passed." -ForegroundColor Green
}
finally {
    Pop-Location
}
