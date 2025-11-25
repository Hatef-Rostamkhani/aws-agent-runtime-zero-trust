output "sns_alerts_topic_arn" {
  description = "ARN of the SNS alerts topic"
  value       = aws_sns_topic.alerts.arn
}

output "main_dashboard_name" {
  description = "Name of the main CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "service_health_dashboard_name" {
  description = "Name of the service health CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.service_health.dashboard_name
}

output "governance_dashboard_name" {
  description = "Name of the governance CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.governance.dashboard_name
}

output "axon_log_group_name" {
  description = "Name of the Axon CloudWatch log group"
  value       = data.aws_cloudwatch_log_group.axon.name
}

output "orbit_log_group_name" {
  description = "Name of the Orbit CloudWatch log group"
  value       = data.aws_cloudwatch_log_group.orbit.name
}

output "governance_log_group_name" {
  description = "Name of the Governance CloudWatch log group"
  value       = data.aws_cloudwatch_log_group.governance.name
}
