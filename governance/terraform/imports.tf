# Import blocks for existing resources
# Terraform 1.5+ will automatically import these resources if they exist
# Note: import block IDs must be literal values (variables not allowed)

import {
  to = aws_dynamodb_table.policies
  id = "agent-runtime-governance-policies"
}

import {
  to = aws_cloudwatch_log_group.governance
  id = "/aws/lambda/agent-runtime-governance"
}

import {
  to = aws_lambda_function.governance
  id = "agent-runtime-governance"
}

import {
  to = aws_iam_role.governance_lambda
  id = "agent-runtime-governance-lambda-role"
}

import {
  to = aws_iam_role_policy.governance_lambda
  id = "agent-runtime-governance-lambda-role:agent-runtime-governance-lambda-policy"
}

