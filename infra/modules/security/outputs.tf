output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "axon_security_group_id" {
  description = "Axon security group ID"
  value       = aws_security_group.axon.id
}

output "orbit_security_group_id" {
  description = "Orbit security group ID"
  value       = aws_security_group.orbit.id
}

output "governance_security_group_id" {
  description = "Governance Lambda security group ID"
  value       = aws_security_group.governance.id
}

