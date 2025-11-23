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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Terraform Backend Setup Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not found${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI installed${NC}"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS credentials configured${NC}"
echo "  Account: $AWS_ACCOUNT"
echo "  Region: $AWS_REGION"
echo ""

# Display configuration
echo -e "${YELLOW}Configuration:${NC}"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  DynamoDB Table: $DYNAMODB_TABLE"
echo "  State Key: $STATE_KEY"
echo "  Region: $AWS_REGION"
echo ""

read -p "Continue with this configuration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""

# ============================================
# S3 Bucket Setup
# ============================================
echo -e "${BLUE}[1/2] Setting up S3 bucket...${NC}"

# Check if bucket already exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠ S3 bucket '$BUCKET_NAME' already exists${NC}"
    
    # Verify versioning
    VERSIONING_STATUS=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --query 'Status' --output text 2>/dev/null || echo "None")
    if [ "$VERSIONING_STATUS" != "Enabled" ]; then
        echo "  Enabling versioning..."
        aws s3api put-bucket-versioning \
            --bucket "$BUCKET_NAME" \
            --versioning-configuration Status=Enabled
        echo -e "${GREEN}✓ Versioning enabled${NC}"
    else
        echo -e "${GREEN}✓ Versioning already enabled${NC}"
    fi
    
    # Verify encryption
    ENCRYPTION=$(aws s3api get-bucket-encryption --bucket "$BUCKET_NAME" --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text 2>/dev/null || echo "None")
    if [ "$ENCRYPTION" == "None" ] || [ -z "$ENCRYPTION" ]; then
        echo "  Enabling encryption..."
        aws s3api put-bucket-encryption \
            --bucket "$BUCKET_NAME" \
            --server-side-encryption-configuration '{
                "Rules": [{
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }]
            }'
        echo -e "${GREEN}✓ Encryption enabled${NC}"
    else
        echo -e "${GREEN}✓ Encryption already enabled${NC}"
    fi
else
    echo "  Creating S3 bucket '$BUCKET_NAME'..."
    
    # Create bucket
    if [ "$AWS_REGION" == "us-east-1" ]; then
        # us-east-1 doesn't need LocationConstraint
        aws s3 mb s3://"$BUCKET_NAME" --region "$AWS_REGION"
    else
        aws s3 mb s3://"$BUCKET_NAME" --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ S3 bucket created${NC}"
    else
        echo -e "${RED}✗ Failed to create S3 bucket${NC}"
        exit 1
    fi
    
    # Enable versioning
    echo "  Enabling versioning..."
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Versioning enabled${NC}"
    else
        echo -e "${RED}✗ Failed to enable versioning${NC}"
        exit 1
    fi
    
    # Enable encryption
    echo "  Enabling encryption..."
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Encryption enabled${NC}"
    else
        echo -e "${RED}✗ Failed to enable encryption${NC}"
        exit 1
    fi
fi

# Verify S3 bucket
echo "  Verifying S3 bucket..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    VERSIONING=$(aws s3api get-bucket-versioning --bucket "$BUCKET_NAME" --query 'Status' --output text 2>/dev/null || echo "None")
    ENCRYPTION=$(aws s3api get-bucket-encryption --bucket "$BUCKET_NAME" --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text 2>/dev/null || echo "None")
    
    if [ "$VERSIONING" == "Enabled" ] && [ "$ENCRYPTION" == "AES256" ]; then
        echo -e "${GREEN}✓ S3 bucket verified: versioning and encryption enabled${NC}"
    else
        echo -e "${RED}✗ S3 bucket verification failed${NC}"
        echo "  Versioning: $VERSIONING"
        echo "  Encryption: $ENCRYPTION"
        exit 1
    fi
else
    echo -e "${RED}✗ S3 bucket verification failed: bucket does not exist${NC}"
    exit 1
fi

echo ""

# ============================================
# DynamoDB Table Setup
# ============================================
echo -e "${BLUE}[2/2] Setting up DynamoDB table...${NC}"

# Check if table already exists
TABLE_EXISTS=$(aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --query 'Table.TableStatus' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$TABLE_EXISTS" != "NOT_FOUND" ]; then
    if [ "$TABLE_EXISTS" == "ACTIVE" ]; then
        echo -e "${YELLOW}⚠ DynamoDB table '$DYNAMODB_TABLE' already exists and is active${NC}"
        echo -e "${GREEN}✓ DynamoDB table ready${NC}"
    else
        echo -e "${YELLOW}⚠ DynamoDB table '$DYNAMODB_TABLE' exists but status is: $TABLE_EXISTS${NC}"
        echo "  Waiting for table to become active..."
        aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE"
        echo -e "${GREEN}✓ DynamoDB table is now active${NC}"
    fi
else
    echo "  Creating DynamoDB table '$DYNAMODB_TABLE'..."
    
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ DynamoDB table created${NC}"
        echo "  Waiting for table to become active..."
        aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE"
        echo -e "${GREEN}✓ DynamoDB table is active${NC}"
    else
        echo -e "${RED}✗ Failed to create DynamoDB table${NC}"
        exit 1
    fi
fi

# Verify DynamoDB table
echo "  Verifying DynamoDB table..."
TABLE_STATUS=$(aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --query 'Table.TableStatus' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$TABLE_STATUS" == "ACTIVE" ]; then
    echo -e "${GREEN}✓ DynamoDB table verified: status is ACTIVE${NC}"
else
    echo -e "${RED}✗ DynamoDB table verification failed: status is $TABLE_STATUS${NC}"
    exit 1
fi

echo ""

# ============================================
# Summary
# ============================================
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Backend Configuration:${NC}"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  DynamoDB Table: $DYNAMODB_TABLE"
echo "  State Key: $STATE_KEY"
echo "  Region: $AWS_REGION"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Configure GitHub Secrets:"
echo "   - TERRAFORM_STATE_BUCKET=$BUCKET_NAME"
echo "   - TERRAFORM_STATE_DYNAMODB_TABLE=$DYNAMODB_TABLE"
echo "   - TERRAFORM_STATE_KEY=$STATE_KEY"
echo "   - AWS_REGION=$AWS_REGION"
echo ""
echo "2. Initialize Terraform:"
echo "   cd infra"
echo "   terraform init \\"
echo "     -backend-config=\"bucket=$BUCKET_NAME\" \\"
echo "     -backend-config=\"dynamodb_table=$DYNAMODB_TABLE\" \\"
echo "     -backend-config=\"key=$STATE_KEY\""
echo ""
echo "3. Or use environment variables:"
echo "   export TERRAFORM_STATE_BUCKET=$BUCKET_NAME"
echo "   export TERRAFORM_STATE_DYNAMODB_TABLE=$DYNAMODB_TABLE"
echo "   export TERRAFORM_STATE_KEY=$STATE_KEY"
echo "   cd infra && terraform init"
echo ""

