param(
    [string]$Profile = $env:AWS_PROFILE,
    [string]$Region = "eu-north-1",
    [switch]$AutoApprove
)

. "$PSScriptRoot/common.ps1"

Set-AwsEnvironment -Profile $Profile -Region $Region
Assert-AwsAuthentication
Initialize-Terraform

if (-not $AutoApprove) {
    $answer = Read-Host "This will destroy the Terraform-managed AWS infrastructure. Type 'yes' to continue"
    if ($answer -ne "yes") {
        Write-Host "Destroy cancelled."
        exit 0
    }
}

$root = Get-ProjectRoot
Push-Location $root
try {
    if ($AutoApprove) {
        terraform destroy -input=false -auto-approve
    }
    else {
        terraform destroy -input=false -auto-approve
    }

    if ($LASTEXITCODE -ne 0) { throw "terraform destroy failed." }
    Write-Host "Terraform-managed AWS infrastructure destroyed successfully." -ForegroundColor Green
}
finally {
    Pop-Location
}
