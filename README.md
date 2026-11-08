# Highly Available AWS Webpage with Terraform

This project deploys a simple webpage on AWS using a highly available and scalable architecture. The infrastructure is defined as code with Terraform so that another user can reproduce the deployment, test it and remove it again in a controlled way.

## Architecture

Request flow:

`Global user -> Amazon CloudFront -> Application Load Balancer -> EC2 Auto Scaling Group`

The solution uses:

- Amazon CloudFront as the global HTTPS entry point and content delivery network.
- An internet-facing Application Load Balancer distributed across two Availability Zones.
- An EC2 Auto Scaling Group with two instances by default and a maximum capacity of four.
- Target-tracking scaling based on average EC2 CPU utilisation with a target of 50%.
- Separate security groups so the EC2 web servers accept HTTP traffic only from the ALB security group.
- Amazon Linux 2023 and Apache HTTP Server for the sample website.
- Terraform to provision and destroy the complete AWS environment.

## Repository structure

```text
.
|-- .github/workflows/terraform-validate.yml
|-- scripts/
|   |-- common.ps1
|   |-- validate.ps1
|   |-- deploy.ps1
|   |-- test.ps1
|   |-- destroy.ps1
|   `-- full-test.ps1
|-- website/
|   |-- index.html
|   |-- style.css
|   `-- error.html
|-- main.tf
|-- variables.tf
|-- outputs.tf
|-- versions.tf
|-- terraform.tfvars.example
|-- user_data.sh.tftpl
`-- README.md
```

## Quick start

Clone the repository and enter the project directory:

```powershell
git clone https://github.com/Reimen123/aws-high-availability-webpage.git
cd aws-high-availability-webpage
```

For a complete end-to-end verification in one command:

```powershell
.\scripts\full-test.ps1 -Profile my-profile
```

This validates the Terraform project, deploys the AWS environment and runs the functional tests. It intentionally leaves the infrastructure running so the results can be inspected. Add `-DestroyAfterTest` when you deliberately want the same workflow to clean up after a successful test.

## Prerequisites

Install the following tools before running the project:

- Terraform 1.6 or later. The final project was tested with Terraform 1.16.2.
- AWS CLI v2.
- PowerShell 7 or later.
- An AWS account and AWS CLI credentials with permission to create the resources defined in this project.

Check the installed tools:

```powershell
terraform version
aws --version
pwsh --version
```

## AWS authentication

The automation scripts use the normal AWS credential chain. If an AWS CLI profile is already configured, pass its name to the scripts:

```powershell
.\scripts\validate.ps1 -Profile my-profile
```

For an AWS CLI login-based profile, refresh the login first if necessary. If Terraform cannot consume that login profile directly, use an AWS CLI `credential_process` profile and pass that profile name to the scripts. No AWS access keys or credentials should be stored in this repository.

The default AWS region is `eu-north-1`. It can be overridden with the `-Region` parameter.

## Configuration

The default values are defined in `variables.tf`:

- Region: `eu-north-1`
- Instance type: `t3.micro`
- Minimum Auto Scaling capacity: `2`
- Desired Auto Scaling capacity: `2`
- Maximum Auto Scaling capacity: `4`
- Target CPU utilisation: `50%`

To override variable values, copy the example file:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Then edit `terraform.tfvars`. The real `terraform.tfvars` file is ignored by Git.

## Automated validation

Run the validation script before deployment:

```powershell
.\scripts\validate.ps1 -Profile my-profile
```

It performs:

1. AWS authentication verification.
2. `terraform init`.
3. `terraform fmt -check -recursive`.
4. `terraform validate`.
5. `terraform plan`.

If all steps pass, the configuration is syntactically valid and Terraform can create a complete execution plan.

GitHub Actions also runs formatting, initialization and Terraform validation automatically on every push and pull request to `main`. The CI workflow does not deploy AWS resources and therefore does not require AWS credentials.

## Automated deployment

Deploy the infrastructure with:

```powershell
.\scripts\deploy.ps1 -Profile my-profile
```

The script verifies authentication, validates the Terraform project, creates an execution plan and then applies it. Because the project creates billable AWS resources, the script requires explicit confirmation before deployment.

For a deliberately non-interactive run:

```powershell
.\scripts\deploy.ps1 -Profile my-profile -AutoApprove
```

After a successful deployment Terraform prints the CloudFront URL, ALB URL, Auto Scaling Group name and other outputs.

## Automated functional test

After deployment run:

```powershell
.\scripts\test.ps1 -Profile my-profile
```

The test verifies that:

- the direct ALB endpoint returns HTTP 200;
- the CloudFront HTTPS endpoint returns HTTP 200;
- a missing CloudFront path returns the custom HTTP 404 response;
- the Auto Scaling Group has the expected minimum and maximum capacity and at least two `InService` instances;
- at least two ALB targets are healthy;
- the CloudFront distribution is in the `Deployed` state.

The HTTP checks retry while AWS services finish becoming available.

## Auto Scaling verification

The normal target-tracking policy keeps average EC2 CPU utilisation near 50%. The final configuration uses:

```text
minimum capacity: 2
desired capacity: 2
maximum capacity: 4
target CPU: 50%
```

During development, load testing was used to verify dynamic scaling from two instances to four and subsequent scale-in when the additional capacity was no longer required. The final submitted configuration retains the 50% CPU target.

## Cleanup

Remove all Terraform-managed AWS resources after testing to avoid unnecessary costs:

```powershell
.\scripts\destroy.ps1 -Profile my-profile
```

The script asks for explicit confirmation. For a deliberately non-interactive cleanup:

```powershell
.\scripts\destroy.ps1 -Profile my-profile -AutoApprove
```

After destruction, Terraform should report that all managed resources have been destroyed.

## Security and repository hygiene

Do not commit:

- AWS access keys, secret keys or session tokens;
- `.aws` configuration files;
- Terraform state files;
- `.terraform/`;
- a real `terraform.tfvars` containing sensitive values.

The `.terraform.lock.hcl` file should be committed. It records provider selections and improves reproducibility.

## Continuous validation

The workflow in `.github/workflows/terraform-validate.yml` performs static Terraform validation on GitHub. This gives every pushed change an automatic quality check before final submission without granting GitHub access to the AWS account.

## Cost notice

This project creates billable AWS resources, including EC2 instances, an Application Load Balancer and CloudFront resources. Deploy only for the required test period and run the destroy script after collecting the required evidence.

## Infrastructure lifecycle

The intended reproducible workflow can be run step by step:

```powershell
.\scripts\validate.ps1 -Profile my-profile
.\scripts\deploy.ps1   -Profile my-profile
.\scripts\test.ps1     -Profile my-profile
.\scripts\destroy.ps1  -Profile my-profile
```

Or the validation, deployment and functional testing can be executed as one automated flow:

```powershell
.\scripts\full-test.ps1 -Profile my-profile
```

This sequence implements the tutor feedback for the finalisation phase: the infrastructure can be validated, deployed, functionally tested and removed through repeatable scripts rather than a manual series of Terraform and AWS commands.
