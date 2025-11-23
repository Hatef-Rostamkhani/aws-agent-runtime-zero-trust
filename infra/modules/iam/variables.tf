variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "axon_kms_key_arn" {
  description = "Axon KMS key ARN"
  type        = string
}

variable "orbit_kms_key_arn" {
  description = "Orbit KMS key ARN"
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

variable "governance_lambda_arn" {
  description = "Governance Lambda function ARN (optional, can be empty initially)"
  type        = string
  default     = ""
}

