resource "aws_kms_key" "axon" {
  description             = "KMS key for Axon service encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  # Policy will be set via aws_kms_key_policy resource in main.tf
  # This allows us to reference IAM roles that are created later
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = ["kms:*"]
        Resource = ["*"]
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-axon-key"
  }
}

resource "aws_kms_key" "orbit" {
  description             = "KMS key for Orbit service encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  # Policy will be set via aws_kms_key_policy resource in main.tf
  # This allows us to reference IAM roles that are created later
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = ["kms:*"]
        Resource = ["*"]
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-orbit-key"
  }
}

resource "aws_kms_alias" "axon" {
  name          = "alias/${var.project_name}-axon"
  target_key_id = aws_kms_key.axon.key_id
}

resource "aws_kms_alias" "orbit" {
  name          = "alias/${var.project_name}-orbit"
  target_key_id = aws_kms_key.orbit.key_id
}

