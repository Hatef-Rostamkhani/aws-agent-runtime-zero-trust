#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BUCKET_NAME="${TERRAFORM_STATE_BUCKET:-agent-runtime-tfstate}"
DYNAMODB_TABLE="${TERRAFORM_STATE_DYNAMODB_TABLE:-agent-runtime-tfstate-lock}"
AWS_REGION="${AWS_REGION:-us-east-1}"
STATE_KEY="${TERRAFORM_STATE_KEY:-agent-runtime/terraform.tfstate}"
PROJECT_NAME="${PROJECT_NAME:-agent-runtime}"
ENVIRONMENT="${ENVIRONMENT:-staging}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}First Terraform Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -d "infra" ]; then
    echo -e "${RED}✗ Error: 'infra' directory not found${NC}"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform not found${NC}"
    echo "Please install Terraform: https://www.terraform.io/downloads"
    exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
echo -e "${GREEN}✓ Terraform $TERRAFORM_VERSION installed${NC}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not found${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS credentials not configured${NC}"
    exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS credentials configured${NC}"
echo "  Account: $AWS_ACCOUNT"
echo "  Region: $AWS_REGION"
echo ""

# Verify backend resources exist
echo -e "${YELLOW}Verifying backend resources...${NC}"

if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${RED}✗ S3 bucket '$BUCKET_NAME' does not exist${NC}"
    echo "Please run ./scripts/setup-terraform-backend.sh first"
    exit 1
fi
echo -e "${GREEN}✓ S3 bucket exists${NC}"

TABLE_STATUS=$(aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --query 'Table.TableStatus' --output text 2>/dev/null || echo "NOT_FOUND")
if [ "$TABLE_STATUS" != "ACTIVE" ]; then
    echo -e "${RED}✗ DynamoDB table '$DYNAMODB_TABLE' does not exist or is not active${NC}"
    echo "Please run ./scripts/setup-terraform-backend.sh first"
    exit 1
fi
echo -e "${GREEN}✓ DynamoDB table exists and is active${NC}"
echo ""

# Display configuration
echo -e "${YELLOW}Deployment Configuration:${NC}"
echo "  Project: $PROJECT_NAME"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $AWS_REGION"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  DynamoDB Table: $DYNAMODB_TABLE"
echo "  State Key: $STATE_KEY"
echo ""

read -p "Continue with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""

# Change to infra directory
cd infra

# Initialize Terraform
echo -e "${BLUE}[1/4] Initializing Terraform...${NC}"
terraform init \
    -backend-config="bucket=$BUCKET_NAME" \
    -backend-config="dynamodb_table=$DYNAMODB_TABLE" \
    -backend-config="key=$STATE_KEY" \
    -backend-config="region=$AWS_REGION"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Terraform initialized${NC}"
else
    echo -e "${RED}✗ Terraform initialization failed${NC}"
    exit 1
fi

echo ""

# Format check
echo -e "${BLUE}[2/4] Checking Terraform format...${NC}"
if terraform fmt -check -recursive; then
    echo -e "${GREEN}✓ Terraform files are properly formatted${NC}"
else
    echo -e "${YELLOW}⚠ Some files need formatting. Running terraform fmt...${NC}"
    terraform fmt -recursive
    echo -e "${GREEN}✓ Files formatted${NC}"
fi

echo ""

# Validate
echo -e "${BLUE}[3/4] Validating Terraform configuration...${NC}"
if terraform validate; then
    echo -e "${GREEN}✓ Terraform configuration is valid${NC}"
else
    echo -e "${RED}✗ Terraform validation failed${NC}"
    exit 1
fi

echo ""

# Plan
echo -e "${BLUE}[4/4] Running Terraform plan...${NC}"
terraform plan \
    -out=tfplan \
    -var="project_name=$PROJECT_NAME" \
    -var="environment=$ENVIRONMENT" \
    -var="aws_region=$AWS_REGION"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Terraform plan completed${NC}"
else
    echo -e "${RED}✗ Terraform plan failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Plan Summary:${NC}"
terraform show -json tfplan | grep -o '"planned_values":{[^}]*}' | head -1 || echo "Review plan output above"

echo ""
read -p "Apply this plan? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Plan saved to tfplan. Run 'terraform apply tfplan' when ready."
    exit 0
fi

echo ""

# Apply
echo -e "${BLUE}Applying Terraform configuration...${NC}"
terraform apply tfplan

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Deployment Successful!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Get important outputs
    echo -e "${YELLOW}Infrastructure Outputs:${NC}"
    terraform output -json | jq -r 'to_entries[] | "  \(.key): \(.value.value)"' 2>/dev/null || terraform output
    
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    
    # Get GitHub Actions IAM role ARN
    INFRA_ROLE_ARN=$(terraform output -raw github_actions_infra_role_arn 2>/dev/null || echo "")
    if [ -n "$INFRA_ROLE_ARN" ] && [ "$INFRA_ROLE_ARN" != "" ]; then
        echo "1. Add GitHub Secret:"
        echo "   AWS_INFRA_DEPLOY_ROLE=$INFRA_ROLE_ARN"
        echo ""
    fi
    
    echo "2. Configure GitHub Secrets:"
    echo "   - AWS_REGION=$AWS_REGION"
    echo "   - TERRAFORM_STATE_BUCKET=$BUCKET_NAME"
    echo "   - TERRAFORM_STATE_DYNAMODB_TABLE=$DYNAMODB_TABLE"
    echo "   - TERRAFORM_STATE_KEY=$STATE_KEY"
    if [ -n "$INFRA_ROLE_ARN" ]; then
        echo "   - AWS_INFRA_DEPLOY_ROLE=$INFRA_ROLE_ARN"
    fi
    echo ""
    echo "3. Future deployments will be automated via GitHub Actions!"
    echo ""
else
    echo ""
    echo -e "${RED}✗ Deployment failed${NC}"
    echo "Review the error messages above"
    exit 1
fi

