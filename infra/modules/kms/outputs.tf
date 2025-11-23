output "axon_key_id" {
  description = "Axon KMS key ID"
  value       = aws_kms_key.axon.key_id
}

output "axon_key_arn" {
  description = "Axon KMS key ARN"
  value       = aws_kms_key.axon.arn
}

output "orbit_key_id" {
  description = "Orbit KMS key ID"
  value       = aws_kms_key.orbit.key_id
}

output "orbit_key_arn" {
  description = "Orbit KMS key ARN"
  value       = aws_kms_key.orbit.arn
}

