terraform {
  backend "s3" {
    # Backend configuration will be provided via backend-config.tfvars
    # or environment variables during terraform init
    # Example: terraform init -backend-config="bucket=your-terraform-state-bucket"

    # Required: S3 bucket name for state storage
    # bucket = "your-terraform-state-bucket"

    # Required: DynamoDB table for state locking
    # dynamodb_table = "terraform-state-lock"

    # Optional: Key prefix for state file
    # key = "agent-runtime/terraform.tfstate"

    # Optional: Region (defaults to provider region)
    # region = "us-east-1"

    # Enable encryption
    encrypt = true
  }
}

