# Import blocks for existing resources
# Terraform 1.5+ will automatically import these resources if they exist

import {
  to = aws_dynamodb_table.policies
  id = "${var.project_name}-governance-policies"
}

import {
  to = aws_cloudwatch_log_group.governance
  id = "/aws/lambda/${var.project_name}-governance"
}

import {
  to = aws_lambda_function.governance
  id = "${var.project_name}-governance"
}

import {
  to = aws_iam_role.governance_lambda
  id = "${var.project_name}-governance-lambda-role"
}

import {
  to = aws_iam_role_policy.governance_lambda
  id = "${var.project_name}-governance-lambda-role:${var.project_name}-governance-lambda-policy"
}

