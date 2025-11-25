resource "aws_lambda_function" "governance" {
  function_name = "${var.project_name}-governance"
  runtime       = "python3.9"
  handler       = "handler.lambda_handler"
  timeout       = 30
  memory_size   = 256

  filename         = "${path.module}/../../governance-artifact/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/../../governance-artifact/lambda.zip")

  role = aws_iam_role.governance_lambda.arn

  environment {
    variables = {
      POLICY_TABLE_NAME = aws_dynamodb_table.policies.name
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.governance_security_group_id]
  }

  tags = {
    Name        = "${var.project_name}-governance"
    Service     = "governance"
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy.governance_lambda,
    aws_cloudwatch_log_group.governance
  ]
}

# Lambda permission is not needed here since Orbit's IAM role already has
# lambda:InvokeFunction permission via IAM boundaries.
# The Lambda permission resource is typically used for API Gateway or
# other service integrations, not for direct IAM role invocations.

