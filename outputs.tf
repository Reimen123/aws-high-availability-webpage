output "alb_url" {
  value = "http://${aws_lb.web.dns_name}"
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.web.domain_name}"
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.web.name
}

output "availability_zones" {
  value = local.azs
}
