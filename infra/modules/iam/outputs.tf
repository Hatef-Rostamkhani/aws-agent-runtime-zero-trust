output "axon_role_arn" {
  description = "Axon IAM role ARN"
  value       = aws_iam_role.axon.arn
}

output "orbit_role_arn" {
  description = "Orbit IAM role ARN"
  value       = aws_iam_role.orbit.arn
}

output "governance_lambda_arn" {
  description = "Governance Lambda ARN (for reference)"
  value       = var.governance_lambda_arn
}

