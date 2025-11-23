variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = ""
}

variable "governance_lambda_arn" {
  description = "Governance Lambda function ARN"
  type        = string
  default     = ""
}

variable "axon_secret_arn" {
  description = "Axon secret ARN"
  type        = string
  default     = ""
}

variable "orbit_secret_arn" {
  description = "Orbit secret ARN"
  type        = string
  default     = ""
}

