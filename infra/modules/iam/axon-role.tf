resource "aws_iam_role" "axon" {
  name                 = "${var.project_name}-axon-role"
  permissions_boundary = aws_iam_policy.axon_boundary.arn

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
    Name = "${var.project_name}-axon-role"
  }
}

resource "aws_iam_role_policy_attachment" "axon_execution" {
  role       = aws_iam_role.axon.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Inline policy for Task Role to access Secrets Manager and KMS
# This allows the application running in the container to read secrets
resource "aws_iam_role_policy" "axon_secrets" {
  name = "${var.project_name}-axon-secrets"
  role = aws_iam_role.axon.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.axon_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.axon_kms_key_arn
      }
    ]
  })
}

