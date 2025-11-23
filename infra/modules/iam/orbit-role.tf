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

