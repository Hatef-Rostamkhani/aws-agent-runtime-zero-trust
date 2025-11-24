resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
  ]

  tags = {
    Name = "${var.project_name}-github-oidc"
  }
}

# IAM Role for Application Deployments (less privileged)
resource "aws_iam_role" "github_actions_app" {
  count = var.github_org != "" && var.github_repo != "" ? 1 : 0
  name  = "${var.project_name}-github-actions-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_org}/${var.github_repo}:*",
              "repo:${var.github_org}/${var.github_repo}:environment:*",
              "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-github-actions-app-role"
  }
}

resource "aws_iam_role_policy" "github_actions_app" {
  count = var.github_org != "" && var.github_repo != "" ? 1 : 0
  name  = "${var.project_name}-github-actions-app-policy"
  role  = aws_iam_role.github_actions_app[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTasks",
          "ecs:DescribeTasks"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:InvokeFunction"
        ]
        Resource = var.governance_lambda_arn != "" ? var.governance_lambda_arn : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = concat(
          var.axon_secret_arn != "" ? [var.axon_secret_arn] : [],
          var.orbit_secret_arn != "" ? [var.orbit_secret_arn] : []
        )
      }
    ]
  })
}

# IAM Role for Infrastructure Deployments (more privileged)
resource "aws_iam_role" "github_actions_infra" {
  count = var.github_org != "" && var.github_repo != "" ? 1 : 0
  name  = "${var.project_name}-github-actions-infra-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_org}/${var.github_repo}:*",
              "repo:${var.github_org}/${var.github_repo}:environment:*",
              "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-github-actions-infra-role"
  }
}

resource "aws_iam_role_policy" "github_actions_infra" {
  count = var.github_org != "" && var.github_repo != "" ? 1 : 0
  name  = "${var.project_name}-github-actions-infra-policy"
  role  = aws_iam_role.github_actions_infra[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "ecs:*",
          "rds:*",
          "lambda:*",
          "iam:*",
          "kms:*",
          "secretsmanager:*",
          "cloudwatch:*",
          "logs:*",
          "apigateway:*",
          "elasticloadbalancing:*",
          "route53:*",
          "s3:*",
          "dynamodb:*",
          "appmesh:*"
        ]
        Resource = "*"
      }
    ]
  })
}

