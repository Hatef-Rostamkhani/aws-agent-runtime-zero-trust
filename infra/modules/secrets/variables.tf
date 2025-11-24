variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "axon_kms_key_id" {
  description = "Axon KMS key ID"
  type        = string
}

variable "orbit_kms_key_id" {
  description = "Orbit KMS key ID"
  type        = string
}

