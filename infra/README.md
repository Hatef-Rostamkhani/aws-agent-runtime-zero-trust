# Infrastructure as Code

This directory contains Terraform configuration for deploying the AWS Agent Runtime infrastructure.

## Overview

The infrastructure includes:
- Multi-AZ VPC with public, private, and isolated subnets
- ECS Fargate cluster with ECR repositories
- AWS App Mesh for service-to-service communication
- Application Load Balancer (internal)
- KMS keys and Secrets Manager for encryption
- IAM roles with permission boundaries
- GitHub OIDC for CI/CD authentication

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- S3 bucket for Terraform state storage
- DynamoDB table for state locking

## Setup

### 1. Create S3 Bucket and DynamoDB Table

```bash
# Create S3 bucket for state
aws s3 mb s3://your-terraform-state-bucket --region us-east-1
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. Configure Backend

Create `backend-config.tfvars`:

```hcl
bucket         = "your-terraform-state-bucket"
dynamodb_table = "terraform-state-lock"
key            = "agent-runtime/terraform.tfstate"
region         = "us-east-1"
```

Or set environment variables:
```bash
export TF_VAR_terraform_state_bucket="your-terraform-state-bucket"
export TF_VAR_terraform_state_dynamodb_table="terraform-state-lock"
export TF_VAR_terraform_state_key="agent-runtime/terraform.tfstate"
```

### 3. Initialize Terraform

```bash
cd infra
terraform init -backend-config=backend-config.tfvars
```

### 4. Configure Variables

Copy and edit `terraform.tfvars.example`:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 5. Plan and Apply

```bash
# Review changes
terraform plan

# Apply infrastructure
terraform apply
```

## Module Structure

```
infra/
├── main.tf                 # Root module with provider and module calls
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── backend.tf             # Backend configuration
├── terraform.tfvars.example  # Example variable values
└── modules/
    ├── networking/        # VPC, subnets, routing, NACLs
    ├── security/          # Security groups
    ├── ecs/              # ECS cluster, ECR, IAM, CloudWatch
    ├── appmesh/          # App Mesh mesh, virtual nodes, service discovery
    ├── alb/              # Application Load Balancer
    ├── kms/              # KMS keys and policies
    ├── secrets/          # Secrets Manager secrets
    ├── iam/              # IAM roles and permission boundaries
    └── cicd/             # GitHub OIDC provider and roles
```

## Deployment via GitHub Actions

The infrastructure can be deployed automatically via GitHub Actions when changes are pushed to the `infra/` directory.

### Required GitHub Secrets

**AWS Configuration:**
- `AWS_REGION`: AWS region (e.g., us-east-1)
- `AWS_INFRA_DEPLOY_ROLE`: ARN of the infrastructure deployment IAM role

**Terraform Backend:**
- `TERRAFORM_STATE_BUCKET`: S3 bucket name for Terraform state
- `TERRAFORM_STATE_DYNAMODB_TABLE`: DynamoDB table name for state locking
- `TERRAFORM_STATE_KEY`: S3 key prefix for state file

**Terraform Variables (Optional - defaults will be used if not set):**
- `TF_VAR_PROJECT_NAME`: Project name (default: "agent-runtime")
- `TF_VAR_VPC_CIDR`: VPC CIDR block (default: "10.0.0.0/16")
- `TF_VAR_AVAILABILITY_ZONES`: JSON array of availability zones (default: `["us-east-1a", "us-east-1b", "us-east-1c"]`)
  - **Note**: For list variables, use JSON format. Example: `["us-east-1a", "us-east-1b", "us-east-1c"]`
- `TF_VAR_GITHUB_ORG`: GitHub organization name (default: "Hatef-Rostamkhani")
- `TF_VAR_GITHUB_REPO`: GitHub repository name (default: "aws-agent-runtime-zero-trust")

**Note**: All Terraform variables use the `TF_VAR_` prefix in GitHub Secrets. The workflow automatically reads these environment variables and passes them to Terraform.

### Manual Deployment

You can also trigger deployment manually:

1. Go to Actions tab in GitHub
2. Select "Deploy Infrastructure" workflow
3. Click "Run workflow"
4. Select environment (staging/production)
5. Click "Run workflow"

## Variables

### Required Variables

- `project_name`: Name of the project (used for resource naming)
- `environment`: Environment name (staging, production, etc.)
- `aws_region`: AWS region for resources
- `vpc_cidr`: CIDR block for VPC

### Optional Variables

- `availability_zones`: List of availability zones (defaults to all available)
- `github_org`: GitHub organization name (for CI/CD)
- `github_repo`: GitHub repository name (for CI/CD)

## Outputs

After deployment, you can view outputs:

```bash
terraform output
```

Key outputs:
- `vpc_id`: VPC ID
- `ecs_cluster_name`: ECS cluster name
- `axon_ecr_repository_url`: Axon ECR repository URL
- `orbit_ecr_repository_url`: Orbit ECR repository URL
- `alb_dns_name`: ALB DNS name
- `axon_kms_key_arn`: Axon KMS key ARN
- `orbit_kms_key_arn`: Orbit KMS key ARN

## Destroying Infrastructure

To destroy all infrastructure:

```bash
terraform destroy
```

**Warning**: This will delete all resources. Make sure you have backups if needed.

## Troubleshooting

### Backend Configuration Issues

If you see backend configuration errors:

```bash
# Reinitialize with backend config
terraform init -reconfigure -backend-config=backend-config.tfvars
```

### State Lock Issues

If Terraform state is locked:

```bash
# Check for locks
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Module Not Found

If modules aren't found:

```bash
# Reinitialize modules
terraform init -upgrade
```

### GitHub OIDC Authentication Issues

If you see `Not authorized to perform sts:AssumeRoleWithWebIdentity` error:

1. **Verify OIDC Provider exists:**
   ```bash
   aws iam list-open-id-connect-providers
   ```

2. **Check IAM Role trust policy:**
   ```bash
   aws iam get-role --role-name agent-runtime-github-actions-infra-role
   aws iam get-role --role-name agent-runtime-github-actions-app-role
   ```

3. **Verify GitHub variables are set:**
   - Ensure `github_org` and `github_repo` are set in `terraform.tfvars` or GitHub Secrets
   - Check that the values match your actual GitHub organization and repository names

4. **Check GitHub Actions permissions:**
   - Ensure `id-token: write` permission is set in workflow
   - Verify `contents: read` permission is set

5. **Verify Role ARN in GitHub Secrets:**
   - Check that `AWS_INFRA_DEPLOY_ROLE` secret contains the full ARN:
     ```
     arn:aws:iam::<ACCOUNT_ID>:role/agent-runtime-github-actions-infra-role
     ```

6. **Debug OIDC token (in GitHub Actions):**
   Add this step temporarily to see the token subject:
   ```yaml
   - name: Debug OIDC Token
     run: |
       echo "Repository: ${{ github.repository }}"
       echo "Environment: ${{ github.event.inputs.environment || 'production' }}"
   ```

7. **Common issues:**
   - Role not created: Ensure `github_org` and `github_repo` are not empty
   - Wrong ARN: Use full ARN including account ID
   - Trust policy mismatch: Subject must match `repo:ORG/REPO:*` pattern
   - Environment mismatch: If using GitHub Environments, ensure trust policy includes `environment:*` pattern

## Security Considerations

- All resources are tagged for cost tracking and security
- KMS keys have rotation enabled
- Secrets are encrypted at rest
- IAM roles use permission boundaries
- Network ACLs restrict traffic flow
- Security groups follow least-privilege principle

## Cost Estimation

Approximate monthly costs (us-east-1):
- NAT Gateways (3): ~$135
- ECS Fargate (2 tasks, 24/7): ~$50-100
- ALB: ~$20-30
- CloudWatch Logs: ~$10-20
- KMS: ~$1
- Secrets Manager: ~$0.50 per secret

**Total**: ~$220-290/month (excluding data transfer)

## Support

For issues or questions:
- Check Terraform documentation: https://www.terraform.io/docs
- Review AWS service documentation
- Create an issue in the repository

