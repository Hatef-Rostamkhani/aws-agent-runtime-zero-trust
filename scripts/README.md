# Setup Scripts

This directory contains utility scripts for setting up and deploying the infrastructure.

## Scripts Overview

### 1. `setup.sh`
Initial project setup - checks prerequisites and initializes the project.

**Usage:**
```bash
./scripts/setup.sh
```

**What it does:**
- Checks for AWS CLI, Terraform, Docker
- Verifies AWS credentials
- Creates `.env.local` file
- Initializes Terraform modules
- Sets up Git hooks

### 2. `setup-terraform-backend.sh` ⭐ **RUN THIS FIRST**
Creates S3 bucket and DynamoDB table for Terraform state storage.

**Usage:**
```bash
./scripts/setup-terraform-backend.sh
```

**What it does:**
- Creates S3 bucket for Terraform state
- Enables versioning and encryption on S3 bucket
- Creates DynamoDB table for state locking
- Verifies all resources are created correctly

**Configuration:**
You can customize via environment variables:
```bash
export TERRAFORM_STATE_BUCKET="my-custom-bucket-name"
export TERRAFORM_STATE_DYNAMODB_TABLE="my-custom-table-name"
export AWS_REGION="us-west-2"
export TERRAFORM_STATE_KEY="custom/path/terraform.tfstate"
./scripts/setup-terraform-backend.sh
```

**Output:**
- S3 bucket name
- DynamoDB table name
- Instructions for next steps

### 3. `first-deploy.sh` ⭐ **RUN THIS SECOND**
Performs the first Terraform deployment manually (before GitHub Actions can work).

**Usage:**
```bash
./scripts/first-deploy.sh
```

**What it does:**
- Verifies backend resources exist
- Initializes Terraform with backend configuration
- Validates Terraform configuration
- Runs terraform plan
- Applies infrastructure (with confirmation)
- Outputs IAM role ARN for GitHub Actions

**Configuration:**
You can customize via environment variables:
```bash
export PROJECT_NAME="my-project"
export ENVIRONMENT="production"
export AWS_REGION="us-west-2"
./scripts/first-deploy.sh
```

**Output:**
- Infrastructure deployment status
- Important resource outputs (VPC ID, ECS cluster, etc.)
- GitHub Actions IAM role ARN
- Instructions for configuring GitHub Secrets

## Quick Start Workflow

### Step 1: Setup Backend
```bash
# Make sure AWS credentials are configured
aws configure

# Run backend setup
./scripts/setup-terraform-backend.sh
```

### Step 2: First Deployment
```bash
# Deploy infrastructure
./scripts/first-deploy.sh

# Copy the GitHub Actions IAM role ARN from output
```

### Step 3: Configure GitHub Secrets
Go to GitHub → Settings → Secrets and variables → Actions, add:

- `AWS_REGION`: `us-east-1` (or your region)
- `TERRAFORM_STATE_BUCKET`: (from setup script output)
- `TERRAFORM_STATE_DYNAMODB_TABLE`: (from setup script output)
- `TERRAFORM_STATE_KEY`: `agent-runtime/terraform.tfstate`
- `AWS_INFRA_DEPLOY_ROLE`: (from first-deploy.sh output)

### Step 4: Push to GitHub
```bash
git add .
git commit -m "Initial infrastructure setup"
git push origin main
```

After this, GitHub Actions will automatically deploy infrastructure changes when you push to `infra/` directory.

## Troubleshooting

### Script fails with "AWS credentials not configured"
```bash
# Configure AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"
```

### Script fails with "S3 bucket already exists"
The script will detect existing buckets and verify their configuration. If you want to use a different bucket name:
```bash
export TERRAFORM_STATE_BUCKET="different-bucket-name"
./scripts/setup-terraform-backend.sh
```

### Script fails with "DynamoDB table already exists"
Similar to S3, the script will verify existing tables. To use a different table:
```bash
export TERRAFORM_STATE_DYNAMODB_TABLE="different-table-name"
./scripts/setup-terraform-backend.sh
```

### Terraform init fails
Make sure backend resources exist:
```bash
# Verify S3 bucket
aws s3 ls s3://your-bucket-name

# Verify DynamoDB table
aws dynamodb describe-table --table-name your-table-name
```

### First deploy fails with permission errors
Make sure your AWS credentials have permissions for:
- EC2 (VPC, subnets, security groups)
- ECS (clusters, task definitions)
- IAM (roles, policies)
- KMS (keys, policies)
- Secrets Manager
- App Mesh
- CloudWatch Logs

## Manual Steps (Alternative)

If you prefer to run commands manually:

### 1. Create S3 Bucket
```bash
aws s3 mb s3://agent-runtime-tfstate --region us-east-1
aws s3api put-bucket-versioning \
  --bucket agent-runtime-tfstate \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption \
  --bucket agent-runtime-tfstate \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### 2. Create DynamoDB Table
```bash
aws dynamodb create-table \
  --table-name agent-runtime-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 3. Initialize and Deploy Terraform
```bash
cd infra
terraform init \
  -backend-config="bucket=agent-runtime-tfstate" \
  -backend-config="dynamodb_table=agent-runtime-tfstate-lock" \
  -backend-config="key=terraform.tfstate"

terraform plan
terraform apply
```

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `TERRAFORM_STATE_BUCKET` | `agent-runtime-tfstate` | S3 bucket name for Terraform state |
| `TERRAFORM_STATE_DYNAMODB_TABLE` | `agent-runtime-tfstate-lock` | DynamoDB table name for state locking |
| `TERRAFORM_STATE_KEY` | `agent-runtime/terraform.tfstate` | S3 key path for state file |
| `AWS_REGION` | `us-east-1` | AWS region for resources |
| `PROJECT_NAME` | `agent-runtime` | Project name for resource naming |
| `ENVIRONMENT` | `staging` | Environment name (staging/production) |

## Security Notes

- S3 buckets are created with encryption enabled
- DynamoDB tables use pay-per-request billing (no upfront costs)
- All scripts verify AWS credentials before running
- Scripts check for existing resources to avoid duplicates
- Terraform state is encrypted at rest in S3

## Support

For issues:
1. Check script output for specific error messages
2. Verify AWS credentials: `aws sts get-caller-identity`
3. Check AWS service limits in your account
4. Review Terraform documentation: https://www.terraform.io/docs

