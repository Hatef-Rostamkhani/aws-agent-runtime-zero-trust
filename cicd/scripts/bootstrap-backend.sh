#!/bin/bash
set -e

# Bootstrap script for Terraform backend resources
# Creates S3 bucket and DynamoDB table if they don't exist
#
# Usage:
#   ./bootstrap-backend.sh [bucket-name] [table-name] [region]
#
# Example:
#   ./bootstrap-backend.sh my-project-tfstate-123456789 my-project-tfstate-lock us-east-1

STATE_BUCKET=${1:-"${PROJECT_NAME}-tfstate-${AWS_ACCOUNT_ID}"}
STATE_TABLE=${2:-"${PROJECT_NAME}-tfstate-lock"}
AWS_REGION=${3:-"us-east-1"}

echo "========================================="
echo "Bootstrap Terraform Backend"
echo "========================================="
echo "S3 Bucket: $STATE_BUCKET"
echo "DynamoDB Table: $STATE_TABLE"
echo "Region: $AWS_REGION"
echo ""

# Validate AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Error: AWS credentials not configured"
    exit 1
fi

# Create S3 bucket if not exists
echo "Checking S3 bucket..."
if aws s3 ls "s3://$STATE_BUCKET" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Creating S3 bucket: $STATE_BUCKET"
    aws s3 mb "s3://$STATE_BUCKET" --region "$AWS_REGION"
    
    echo "Enabling versioning..."
    aws s3api put-bucket-versioning \
        --bucket "$STATE_BUCKET" \
        --versioning-configuration Status=Enabled
    
    echo "Enabling encryption..."
    aws s3api put-bucket-encryption \
        --bucket "$STATE_BUCKET" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    
    echo "✅ S3 bucket created successfully"
else
    echo "ℹ️  S3 bucket already exists: $STATE_BUCKET"
fi

# Create DynamoDB table if not exists
echo ""
echo "Checking DynamoDB table..."
if aws dynamodb describe-table --table-name "$STATE_TABLE" --region "$AWS_REGION" 2>&1 | grep -q 'ResourceNotFoundException'; then
    echo "Creating DynamoDB table: $STATE_TABLE"
    aws dynamodb create-table \
        --table-name "$STATE_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION"
    
    echo "Waiting for table to be active..."
    aws dynamodb wait table-exists \
        --table-name "$STATE_TABLE" \
        --region "$AWS_REGION"
    
    echo "✅ DynamoDB table created successfully"
else
    echo "ℹ️  DynamoDB table already exists: $STATE_TABLE"
fi

echo ""
echo "========================================="
echo "✅ Bootstrap Complete!"
echo "========================================="
echo ""
echo "Backend Configuration:"
echo "  bucket         = $STATE_BUCKET"
echo "  dynamodb_table = $STATE_TABLE"
echo "  region         = $AWS_REGION"
echo ""

