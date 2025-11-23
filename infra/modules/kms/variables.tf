variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "axon_role_arn" {
  description = "Axon IAM role ARN"
  type        = string
  default     = ""
}

variable "orbit_role_arn" {
  description = "Orbit IAM role ARN"
  type        = string
  default     = ""
}

