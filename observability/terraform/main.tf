terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# This module sets up comprehensive observability for the agent runtime environment
# including CloudWatch dashboards, structured logging, alerting, and tracing
