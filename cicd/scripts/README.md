# CI/CD Scripts

This directory contains utility scripts for CI/CD pipelines.

## bootstrap-backend.sh

Automatically creates S3 bucket and DynamoDB table for Terraform state storage.

### Usage

```bash
./bootstrap-backend.sh [bucket-name] [table-name] [region]
```

### Parameters

- `bucket-name` (optional): S3 bucket name for Terraform state
  - Default: `${PROJECT_NAME}-tfstate-${AWS_ACCOUNT_ID}`
- `table-name` (optional): DynamoDB table name for state locking
  - Default: `${PROJECT_NAME}-tfstate-lock`
- `region` (optional): AWS region
  - Default: `us-east-1`

### Environment Variables

- `PROJECT_NAME`: Project name (used in default bucket/table names)
- `AWS_ACCOUNT_ID`: AWS account ID (used in default bucket name)

### Example

```bash
export PROJECT_NAME="agent-runtime"
export AWS_ACCOUNT_ID="123456789012"

./bootstrap-backend.sh \
  "agent-runtime-tfstate-123456789012" \
  "agent-runtime-tfstate-lock" \
  "us-east-1"
```

### Features

- **Idempotent**: Safe to run multiple times
- **Auto-detection**: Checks if resources exist before creating
- **Error handling**: Exits on errors with clear messages
- **Validation**: Verifies AWS credentials before proceeding

### What It Does

1. Validates AWS credentials
2. Creates S3 bucket if it doesn't exist
3. Enables versioning on S3 bucket
4. Enables encryption on S3 bucket
5. Creates DynamoDB table if it doesn't exist
6. Waits for DynamoDB table to be active
7. Outputs backend configuration

### Integration with GitHub Actions

This script is automatically called by the `deploy-infra.yml` workflow before Terraform initialization.

