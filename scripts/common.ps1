Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ProjectRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Assert-Command {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Set-AwsEnvironment {
    param(
        [string]$Profile,
        [string]$Region = "eu-north-1"
    )

    $env:AWS_REGION = $Region
    $env:AWS_DEFAULT_REGION = $Region

    if (-not [string]::IsNullOrWhiteSpace($Profile)) {
        $env:AWS_PROFILE = $Profile
    }
}

function Assert-AwsAuthentication {
    Assert-Command -Name "aws"

    Write-Host "Checking AWS authentication..." -ForegroundColor Cyan
    $identityJson = aws sts get-caller-identity --output json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "AWS authentication failed. Configure or refresh your AWS CLI credentials before continuing.`n$identityJson"
    }

    $null = $identityJson | ConvertFrom-Json
    Write-Host "AWS authentication successful." -ForegroundColor Green
}

function Initialize-Terraform {
    Assert-Command -Name "terraform"
    Push-Location (Get-ProjectRoot)
    try {
        terraform init -input=false
        if ($LASTEXITCODE -ne 0) { throw "terraform init failed." }
    }
    finally {
        Pop-Location
    }
}

function Invoke-TerraformQualityChecks {
    Push-Location (Get-ProjectRoot)
    try {
        Write-Host "Checking Terraform formatting..." -ForegroundColor Cyan
        terraform fmt -check -recursive
        if ($LASTEXITCODE -ne 0) {
            throw "Terraform formatting check failed. Run 'terraform fmt -recursive' and retry."
        }

        Write-Host "Validating Terraform configuration..." -ForegroundColor Cyan
        terraform validate
        if ($LASTEXITCODE -ne 0) { throw "terraform validate failed." }
    }
    finally {
        Pop-Location
    }
}
