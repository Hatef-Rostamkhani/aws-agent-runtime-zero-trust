# Lambda for secrets rotation
resource "aws_lambda_function" "secrets_rotation" {
  function_name = "${var.project_name}-secrets-rotation"
  runtime       = "python3.9"
  handler       = "rotation.lambda_handler"
  timeout       = 300

  filename         = data.archive_file.rotation_zip.output_path
  source_code_hash = data.archive_file.rotation_zip.output_base64sha256

  role = aws_iam_role.secrets_rotation.arn

  environment {
    variables = {
      SECRETS_TO_ROTATE = jsonencode([
        aws_secretsmanager_secret.axon.name,
        aws_secretsmanager_secret.orbit.name
      ])
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.secrets_rotation.id]
  }

  tags = {
    Name = "${var.project_name}-secrets-rotation"
  }
}

data "archive_file" "rotation_zip" {
  type        = "zip"
  output_path = "${path.module}/rotation.zip"
  source_dir  = "${path.module}/../lambda/rotation"
}

resource "aws_iam_role" "secrets_rotation" {
  name = "${var.project_name}-secrets-rotation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-secrets-rotation-role"
  }
}

resource "aws_iam_role_policy" "secrets_rotation" {
  name = "${var.project_name}-secrets-rotation-policy"
  role = aws_iam_role.secrets_rotation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = [
          aws_secretsmanager_secret.axon.arn,
          aws_secretsmanager_secret.orbit.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/${var.project_name}-secrets-rotation:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_security_group" "secrets_rotation" {
  name_prefix = "${var.project_name}-secrets-rotation-"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-secrets-rotation-sg"
  }
}

# EventBridge rule for scheduled rotation
resource "aws_cloudwatch_event_rule" "secrets_rotation" {
  name                = "${var.project_name}-secrets-rotation-schedule"
  description         = "Rotate secrets every 30 days"
  schedule_expression = "rate(30 days)"

  tags = {
    Name = "${var.project_name}-secrets-rotation-schedule"
  }
}

resource "aws_cloudwatch_event_target" "secrets_rotation" {
  rule      = aws_cloudwatch_event_rule.secrets_rotation.name
  target_id = "secrets-rotation-lambda"
  arn       = aws_lambda_function.secrets_rotation.arn
}

resource "aws_lambda_permission" "secrets_rotation" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secrets_rotation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.secrets_rotation.arn
}
