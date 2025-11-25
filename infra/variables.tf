variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "agent-runtime"
}

variable "environment" {
  description = "Environment name (staging, production, etc.)"
  type        = string
  default     = "staging"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Backend configuration variables (optional, can be set via backend config)
variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = ""
}

variable "terraform_state_dynamodb_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = ""
}

variable "terraform_state_key" {
  description = "S3 key prefix for Terraform state file"
  type        = string
  default     = "agent-runtime/terraform.tfstate"
}

# GitHub OIDC configuration (for CI/CD)
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

variable "governance_function_name" {
  description = "Governance Lambda function name (optional, defaults to project_name-governance)"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address for observability alerts (optional)"
  type        = string
  default     = ""
}

