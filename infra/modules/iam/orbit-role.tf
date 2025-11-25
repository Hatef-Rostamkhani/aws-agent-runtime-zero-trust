resource "aws_iam_role" "orbit" {
  name                 = "${var.project_name}-orbit-role"
  permissions_boundary = aws_iam_policy.orbit_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-orbit-role"
  }
}

resource "aws_iam_role_policy_attachment" "orbit_execution" {
  role       = aws_iam_role.orbit.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Inline policy for Task Role to access Secrets Manager and KMS
# This allows the application running in the container to read secrets
resource "aws_iam_role_policy" "orbit_secrets" {
  name = "${var.project_name}-orbit-secrets"
  role = aws_iam_role.orbit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.orbit_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.orbit_kms_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = var.governance_lambda_arn != "" ? var.governance_lambda_arn : "*"
      }
    ]
  })
}

