param(
    [string]$Profile = $env:AWS_PROFILE,
    [string]$Region = "eu-north-1",
    [int]$MaxAttempts = 20,
    [int]$RetrySeconds = 15
)

. "$PSScriptRoot/common.ps1"

Set-AwsEnvironment -Profile $Profile -Region $Region
Assert-AwsAuthentication
Assert-Command -Name "terraform"

$root = Get-ProjectRoot

function Get-TerraformOutput {
    param([Parameter(Mandatory = $true)][string]$Name)

    Push-Location $root
    try {
        $value = terraform output -raw $Name 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Could not read Terraform output '$Name'. Has the infrastructure been deployed?"
        }
        return $value.Trim()
    }
    finally {
        Pop-Location
    }
}

function Test-HttpEndpoint {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][int]$ExpectedStatus
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $statusCode = $null
        $requestError = $null

        try {
            $response = Invoke-WebRequest -Uri $Uri -Method Get -MaximumRedirection 5 -TimeoutSec 20 -UseBasicParsing -ErrorAction Stop
            $statusCode = [int]$response.StatusCode
        }
        catch {
            $requestError = $_.Exception.Message

            # Windows PowerShell 5.1 throws for HTTP 4xx/5xx responses.
            # If a response exists, capture its status code so expected errors
            # (for example the custom CloudFront 404 page) can still pass.
            if ($null -ne $_.Exception.Response -and $null -ne $_.Exception.Response.StatusCode) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }
        }

        if ($null -ne $statusCode) {
            if ($statusCode -eq $ExpectedStatus) {
                Write-Host "PASS: $Name returned HTTP $ExpectedStatus - $Uri" -ForegroundColor Green
                return
            }

            Write-Host "Attempt $attempt/${MaxAttempts}: ${Name} returned HTTP $statusCode; expected $ExpectedStatus." -ForegroundColor Yellow
        }
        else {
            Write-Host "Attempt $attempt/${MaxAttempts}: ${Name} is not ready: $requestError" -ForegroundColor Yellow
        }

        if ($attempt -lt $MaxAttempts) {
            Start-Sleep -Seconds $RetrySeconds
        }
    }

    throw "FAIL: $Name did not return HTTP $ExpectedStatus after $MaxAttempts attempts."
}

$albUrl = Get-TerraformOutput -Name "alb_url"
$cloudFrontUrl = Get-TerraformOutput -Name "cloudfront_url"
$asgName = Get-TerraformOutput -Name "autoscaling_group_name"
$targetGroupArn = Get-TerraformOutput -Name "target_group_arn"
$distributionId = Get-TerraformOutput -Name "cloudfront_distribution_id"
$expectedMinSize = [int](Get-TerraformOutput -Name "autoscaling_min_size")
$expectedMaxSize = [int](Get-TerraformOutput -Name "autoscaling_max_size")

Write-Host "Testing deployed endpoints..." -ForegroundColor Cyan
Test-HttpEndpoint -Name "Application Load Balancer" -Uri $albUrl -ExpectedStatus 200
Test-HttpEndpoint -Name "CloudFront website" -Uri $cloudFrontUrl -ExpectedStatus 200
Test-HttpEndpoint -Name "CloudFront custom 404" -Uri "$cloudFrontUrl/does-not-exist" -ExpectedStatus 404

Write-Host "Checking Auto Scaling Group..." -ForegroundColor Cyan
$asgJson = aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $asgName --region $Region --output json
if ($LASTEXITCODE -ne 0) { throw "Failed to query the Auto Scaling Group." }
$asg = ($asgJson | ConvertFrom-Json).AutoScalingGroups | Select-Object -First 1
if ($null -eq $asg) { throw "Auto Scaling Group '$asgName' was not found." }

$inServiceCount = @($asg.Instances | Where-Object { $_.LifecycleState -eq "InService" }).Count
if ($asg.MinSize -ne $expectedMinSize -or $asg.MaxSize -ne $expectedMaxSize) {
    throw "FAIL: Expected ASG limits min=$expectedMinSize and max=$expectedMaxSize, found min=$($asg.MinSize), max=$($asg.MaxSize)."
}
if ($inServiceCount -lt $expectedMinSize) {
    throw "FAIL: Expected at least $expectedMinSize InService instances, found $inServiceCount."
}
Write-Host "PASS: Auto Scaling Group min=$($asg.MinSize), desired=$($asg.DesiredCapacity), max=$($asg.MaxSize), InService=$inServiceCount." -ForegroundColor Green

Write-Host "Checking target health..." -ForegroundColor Cyan
$targetJson = aws elbv2 describe-target-health --target-group-arn $targetGroupArn --region $Region --output json
if ($LASTEXITCODE -ne 0) { throw "Failed to query target health." }
$targets = ($targetJson | ConvertFrom-Json).TargetHealthDescriptions
$healthyTargets = @($targets | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
if ($healthyTargets -lt 2) {
    throw "FAIL: Expected at least 2 healthy ALB targets, found $healthyTargets."
}
Write-Host "PASS: $healthyTargets ALB targets are healthy." -ForegroundColor Green

Write-Host "Checking CloudFront deployment state..." -ForegroundColor Cyan
$distributionJson = aws cloudfront get-distribution --id $distributionId --output json
if ($LASTEXITCODE -ne 0) { throw "Failed to query CloudFront distribution." }
$distribution = $distributionJson | ConvertFrom-Json
if ($distribution.Distribution.Status -ne "Deployed") {
    throw "FAIL: CloudFront status is '$($distribution.Distribution.Status)', expected 'Deployed'."
}
Write-Host "PASS: CloudFront distribution is Deployed." -ForegroundColor Green

Write-Host "All automated deployment tests passed." -ForegroundColor Green
