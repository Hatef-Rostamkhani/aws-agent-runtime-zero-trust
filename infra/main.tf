terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Use provided AZs or fallback to available ones
locals {
  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : data.aws_availability_zones.available.names
}

# Networking Module
module "networking" {
  source = "./modules/networking"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = local.availability_zones
}

# Security Module
module "security" {
  source = "./modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  project_name                = var.project_name
  environment                 = var.environment
  vpc_id                      = module.networking.vpc_id
  axon_runtime_subnet_ids     = module.networking.axon_runtime_subnet_ids
  private_subnet_ids          = module.networking.private_subnet_ids
  axon_security_group_id      = module.security.axon_security_group_id
  orbit_security_group_id     = module.security.orbit_security_group_id
  axon_role_arn               = module.iam.axon_role_arn
  orbit_role_arn              = module.iam.orbit_role_arn
  axon_secret_arn             = module.secrets.axon_secret_arn
  orbit_secret_arn            = module.secrets.orbit_secret_arn
  axon_kms_key_arn            = module.kms.axon_key_arn
  orbit_kms_key_arn           = module.kms.orbit_key_arn
  axon_target_group_arn       = module.alb.axon_target_group_arn
  orbit_target_group_arn      = module.alb.orbit_target_group_arn
  axon_listener_rule_arn      = module.alb.axon_listener_rule_arn
  orbit_listener_rule_arn     = module.alb.orbit_listener_rule_arn
  service_discovery_namespace = module.appmesh.service_discovery_namespace
  axon_service_discovery_arn  = module.appmesh.axon_service_discovery_arn
  orbit_service_discovery_arn = module.appmesh.orbit_service_discovery_arn
  aws_region                  = var.aws_region
  governance_function_name    = var.governance_function_name
}

# KMS Module (created first, policies updated after IAM roles exist)
module "kms" {
  source = "./modules/kms"

  project_name   = var.project_name
  environment    = var.environment
  account_id     = data.aws_caller_identity.current.account_id
  axon_role_arn  = "" # Will be updated after IAM roles are created
  orbit_role_arn = "" # Will be updated after IAM roles are created
}

# Secrets Module
module "secrets" {
  source = "./modules/secrets"

  project_name     = var.project_name
  environment      = var.environment
  axon_kms_key_id  = module.kms.axon_key_id
  orbit_kms_key_id = module.kms.orbit_key_id
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  project_name          = var.project_name
  environment           = var.environment
  axon_kms_key_arn      = module.kms.axon_key_arn
  orbit_kms_key_arn     = module.kms.orbit_key_arn
  axon_secret_arn       = module.secrets.axon_secret_arn
  orbit_secret_arn      = module.secrets.orbit_secret_arn
  governance_lambda_arn = "" # Will be added when governance is deployed
}

# Update KMS key policies with IAM role ARNs
resource "aws_kms_key_policy" "axon" {
  key_id     = module.kms.axon_key_id
  depends_on = [module.iam]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = ["kms:*"]
        Resource = ["*"]
      },
      {
        Sid    = "Allow Axon Role"
        Effect = "Allow"
        Principal = {
          AWS = module.iam.axon_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "Deny Orbit Role"
        Effect = "Deny"
        Principal = {
          AWS = module.iam.orbit_role_arn
        }
        Action   = ["kms:*"]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_kms_key_policy" "orbit" {
  key_id     = module.kms.orbit_key_id
  depends_on = [module.iam]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = ["kms:*"]
        Resource = ["*"]
      },
      {
        Sid    = "Allow Orbit Role"
        Effect = "Allow"
        Principal = {
          AWS = module.iam.orbit_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "Deny Axon Role"
        Effect = "Deny"
        Principal = {
          AWS = module.iam.axon_role_arn
        }
        Action   = ["kms:*"]
        Resource = ["*"]
      }
    ]
  })
}

# App Mesh Module
module "appmesh" {
  source = "./modules/appmesh"

  project_name       = var.project_name
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
}

# ALB Module
module "alb" {
  source = "./modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
}

# Observability Module
module "observability" {
  source = "../observability/terraform"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  kms_key_arn  = module.kms.axon_key_arn # Use axon KMS key for encryption
  alert_email  = var.alert_email
}

# CI/CD Module (for GitHub OIDC)
module "cicd" {
  source = "./modules/cicd"

  project_name          = var.project_name
  environment           = var.environment
  github_org            = var.github_org
  github_repo           = var.github_repo
  governance_lambda_arn = module.iam.governance_lambda_arn
  axon_secret_arn       = module.secrets.axon_secret_arn
  orbit_secret_arn      = module.secrets.orbit_secret_arn
}

