resource "aws_cloudwatch_log_group" "axon" {
  name              = "/ecs/${var.project_name}-axon"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-axon-logs"
  }
}

resource "aws_cloudwatch_log_group" "orbit" {
  name              = "/ecs/${var.project_name}-orbit"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-orbit-logs"
  }
}

