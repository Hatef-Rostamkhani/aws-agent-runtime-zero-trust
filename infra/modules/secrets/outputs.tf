output "axon_secret_arn" {
  description = "Axon secret ARN"
  value       = aws_secretsmanager_secret.axon.arn
}

output "orbit_secret_arn" {
  description = "Orbit secret ARN"
  value       = aws_secretsmanager_secret.orbit.arn
}

