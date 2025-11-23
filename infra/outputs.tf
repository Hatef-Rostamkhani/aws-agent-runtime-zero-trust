# Networking Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "axon_runtime_subnet_ids" {
  description = "Axon runtime subnet IDs"
  value       = module.networking.axon_runtime_subnet_ids
}

# Security Outputs
output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = module.security.alb_security_group_id
}

output "axon_security_group_id" {
  description = "Axon security group ID"
  value       = module.security.axon_security_group_id
}

output "orbit_security_group_id" {
  description = "Orbit security group ID"
  value       = module.security.orbit_security_group_id
}

output "governance_security_group_id" {
  description = "Governance Lambda security group ID"
  value       = module.security.governance_security_group_id
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs.cluster_arn
}

output "axon_ecr_repository_url" {
  description = "Axon ECR repository URL"
  value       = module.ecs.axon_repository_url
}

output "orbit_ecr_repository_url" {
  description = "Orbit ECR repository URL"
  value       = module.ecs.orbit_repository_url
}

output "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = module.ecs.task_execution_role_arn
}

# KMS Outputs
output "axon_kms_key_id" {
  description = "Axon KMS key ID"
  value       = module.kms.axon_key_id
}

output "axon_kms_key_arn" {
  description = "Axon KMS key ARN"
  value       = module.kms.axon_key_arn
}

output "orbit_kms_key_id" {
  description = "Orbit KMS key ID"
  value       = module.kms.orbit_key_id
}

output "orbit_kms_key_arn" {
  description = "Orbit KMS key ARN"
  value       = module.kms.orbit_key_arn
}

# Secrets Outputs
output "axon_secret_arn" {
  description = "Axon secret ARN"
  value       = module.secrets.axon_secret_arn
}

output "orbit_secret_arn" {
  description = "Orbit secret ARN"
  value       = module.secrets.orbit_secret_arn
}

# IAM Outputs
output "axon_iam_role_arn" {
  description = "Axon IAM role ARN"
  value       = module.iam.axon_role_arn
}

output "orbit_iam_role_arn" {
  description = "Orbit IAM role ARN"
  value       = module.iam.orbit_role_arn
}

# App Mesh Outputs
output "app_mesh_name" {
  description = "App Mesh name"
  value       = module.appmesh.mesh_name
}

output "app_mesh_arn" {
  description = "App Mesh ARN"
  value       = module.appmesh.mesh_arn
}

output "service_discovery_namespace" {
  description = "Service discovery namespace"
  value       = module.appmesh.service_discovery_namespace
}

# ALB Outputs
output "alb_arn" {
  description = "ALB ARN"
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "alb_target_group_axon_arn" {
  description = "Axon target group ARN"
  value       = module.alb.axon_target_group_arn
}

output "alb_target_group_orbit_arn" {
  description = "Orbit target group ARN"
  value       = module.alb.orbit_target_group_arn
}

