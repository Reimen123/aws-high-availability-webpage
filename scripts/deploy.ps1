param(
    [string]$Profile = $env:AWS_PROFILE,
    [string]$Region = "eu-north-1",
    [switch]$AutoApprove
)

. "$PSScriptRoot/common.ps1"

Set-AwsEnvironment -Profile $Profile -Region $Region
Assert-AwsAuthentication
Initialize-Terraform
Invoke-TerraformQualityChecks

if (-not $AutoApprove) {
    $answer = Read-Host "This deployment creates billable AWS resources. Type 'yes' to continue"
    if ($answer -ne "yes") {
        Write-Host "Deployment cancelled."
        exit 0
    }
}

$root = Get-ProjectRoot
Push-Location $root
try {
    Write-Host "Creating deployment plan..." -ForegroundColor Cyan
    terraform plan -input=false -out=tfplan
    if ($LASTEXITCODE -ne 0) { throw "terraform plan failed." }

    Write-Host "Applying Terraform plan..." -ForegroundColor Cyan
    terraform apply -input=false tfplan
    if ($LASTEXITCODE -ne 0) { throw "terraform apply failed." }

    Remove-Item -Force tfplan -ErrorAction SilentlyContinue

    Write-Host "Deployment complete." -ForegroundColor Green
    terraform output
}
finally {
    Pop-Location
}
