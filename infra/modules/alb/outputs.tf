output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "axon_target_group_arn" {
  description = "Axon target group ARN"
  value       = aws_lb_target_group.axon.arn
}

output "orbit_target_group_arn" {
  description = "Orbit target group ARN"
  value       = aws_lb_target_group.orbit.arn
}

