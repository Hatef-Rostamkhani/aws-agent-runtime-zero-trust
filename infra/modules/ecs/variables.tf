variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "axon_runtime_subnet_ids" {
  description = "Axon runtime subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "axon_security_group_id" {
  description = "Axon security group ID"
  type        = string
}

variable "orbit_security_group_id" {
  description = "Orbit security group ID"
  type        = string
}

variable "axon_role_arn" {
  description = "Axon IAM role ARN"
  type        = string
}

variable "orbit_role_arn" {
  description = "Orbit IAM role ARN"
  type        = string
}

variable "axon_secret_arn" {
  description = "Axon secret ARN"
  type        = string
}

variable "orbit_secret_arn" {
  description = "Orbit secret ARN"
  type        = string
}

variable "axon_target_group_arn" {
  description = "Axon target group ARN"
  type        = string
}

variable "orbit_target_group_arn" {
  description = "Orbit target group ARN"
  type        = string
}

variable "service_discovery_namespace" {
  description = "Service discovery namespace"
  type        = string
}

variable "axon_service_discovery_arn" {
  description = "Axon service discovery ARN"
  type        = string
}

variable "orbit_service_discovery_arn" {
  description = "Orbit service discovery ARN"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "governance_function_name" {
  description = "Governance Lambda function name"
  type        = string
  default     = ""
}

variable "axon_listener_rule_arn" {
  description = "Axon listener rule ARN - ensures target group is associated with ALB"
  type        = string
}

variable "orbit_listener_rule_arn" {
  description = "Orbit listener rule ARN - ensures target group is associated with ALB"
  type        = string
}

variable "axon_kms_key_arn" {
  description = "Axon KMS key ARN for decrypting secrets"
  type        = string
}

variable "orbit_kms_key_arn" {
  description = "Orbit KMS key ARN for decrypting secrets"
  type        = string
}
