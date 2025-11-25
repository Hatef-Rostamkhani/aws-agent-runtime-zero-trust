# Import blocks for existing resources that we know exist
# Only import resources that actually exist to avoid import failures
# Note: import block IDs must be literal values (variables not allowed)

# Import DynamoDB table (created earlier)
import {
  to = aws_dynamodb_table.policies
  id = "agent-runtime-governance-policies"
}

# Import IAM role (created by infra deployment)
import {
  to = aws_iam_role.governance_lambda
  id = "agent-runtime-governance-lambda-role"
}

# Note: Lambda function and CloudWatch log group will be created by Terraform
# IAM role policy will be created by Terraform
# Only import resources that definitely exist to avoid import errors

