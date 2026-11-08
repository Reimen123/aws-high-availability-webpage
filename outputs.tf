output "alb_url" {
  description = "Direct HTTP URL of the Application Load Balancer."
  value       = "http://${aws_lb.web.dns_name}"
}

output "cloudfront_url" {
  description = "Public HTTPS URL delivered through CloudFront."
  value       = "https://${aws_cloudfront_distribution.web.domain_name}"
}

output "autoscaling_group_name" {
  description = "Name of the EC2 Auto Scaling Group."
  value       = aws_autoscaling_group.web.name
}

output "target_group_arn" {
  description = "ARN of the ALB target group, used by the automated health test."
  value       = aws_lb_target_group.web.arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID, used by the automated deployment test."
  value       = aws_cloudfront_distribution.web.id
}

output "availability_zones" {
  description = "Availability Zones used by the public subnets and Auto Scaling Group."
  value       = local.azs
}

output "autoscaling_min_size" {
  description = "Configured minimum Auto Scaling capacity."
  value       = var.min_size
}

output "autoscaling_max_size" {
  description = "Configured maximum Auto Scaling capacity."
  value       = var.max_size
}
