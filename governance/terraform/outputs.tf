output "lambda_function_name" {
  description = "Governance Lambda function name"
  value       = aws_lambda_function.governance.function_name
}

output "lambda_function_arn" {
  description = "Governance Lambda function ARN"
  value       = aws_lambda_function.governance.arn
}

output "dynamodb_table_name" {
  description = "Governance policies DynamoDB table name"
  value       = aws_dynamodb_table.policies.name
}

output "dynamodb_table_arn" {
  description = "Governance policies DynamoDB table ARN"
  value       = aws_dynamodb_table.policies.arn
}

output "lambda_role_arn" {
  description = "Governance Lambda IAM role ARN"
  value       = aws_iam_role.governance_lambda.arn
}

