# AWS Highly Available Webpage

Architecture:
CloudFront -> Application Load Balancer -> EC2 Auto Scaling Group across two Availability Zones.

## Requirements
- AWS account
- Terraform >= 1.6
- AWS CLI credentials configured

## Deploy
```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

After deployment, use the `cloudfront_url` output as the public website.

## Important
This project creates billable resources, including EC2 instances and an Application Load Balancer.

## Destroy
```bash
terraform destroy
```
