#!/bin/bash

set -e

echo "========================================="
echo "AWS Agent Runtime - Zero Trust Setup"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not found${NC}"
    echo "Install: https://aws.amazon.com/cli/"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI installed${NC}"

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform not found${NC}"
    echo "Install: https://www.terraform.io/downloads"
    exit 1
fi
TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
echo -e "${GREEN}✓ Terraform $TERRAFORM_VERSION installed${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found${NC}"
    echo "Install: https://docs.docker.com/get-docker/"
    exit 1
fi
echo -e "${GREEN}✓ Docker installed${NC}"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-east-1}
echo -e "${GREEN}✓ AWS credentials configured${NC}"
echo "  Account: $AWS_ACCOUNT"
echo "  Region: $AWS_REGION"
echo ""

# Create environment file
echo "Creating environment configuration..."
cat > .env.local <<EOF
# AWS Configuration
AWS_ACCOUNT_ID=$AWS_ACCOUNT
AWS_REGION=$AWS_REGION
AWS_PROFILE=${AWS_PROFILE:-default}

# Project Configuration
PROJECT_NAME=agent-runtime
ENVIRONMENT=dev

# Service Configuration
AXON_IMAGE_TAG=latest
ORBIT_IMAGE_TAG=latest

# Terraform Backend (update for your setup)
TF_STATE_BUCKET=${PROJECT_NAME}-tfstate-${AWS_ACCOUNT}
TF_STATE_KEY=terraform.tfstate
TF_DYNAMODB_TABLE=${PROJECT_NAME}-tfstate-lock
EOF
echo -e "${GREEN}✓ Created .env.local${NC}"

# Initialize Terraform modules
echo ""
echo "Initializing Terraform..."
cd infra
terraform init
echo -e "${GREEN}✓ Terraform initialized${NC}"

# Validate Terraform configuration
echo ""
echo "Validating Terraform configuration..."
terraform validate
echo -e "${GREEN}✓ Terraform configuration valid${NC}"

cd ..

# Setup Git hooks (optional)
if [ -d .git ]; then
    echo ""
    echo "Setting up Git hooks..."
    cat > .git/hooks/pre-commit <<'EOF'
#!/bin/bash
# Run Terraform fmt check
terraform fmt -check -recursive infra/ || {
    echo "Terraform formatting issues found. Run 'terraform fmt -recursive infra/'"
    exit 1
}
EOF
    chmod +x .git/hooks/pre-commit
    echo -e "${GREEN}✓ Git hooks configured${NC}"
fi

# Summary
echo ""
echo "========================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Review configuration in .env.local"
echo "2. Update infra/terraform.tfvars with your settings"
echo "3. Deploy infrastructure:"
echo "   cd infra"
echo "   terraform plan -out=tfplan"
echo "   terraform apply tfplan"
echo ""
echo "4. Build and deploy services:"
echo "   ./scripts/build-services.sh"
echo "   ./scripts/deploy-services.sh"
echo ""
echo "For more information, see README.md"

