# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "axon" {
  name              = "/ecs/${var.project_name}-axon"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-axon-logs"
    Service     = "axon"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "orbit" {
  name              = "/ecs/${var.project_name}-orbit"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-orbit-logs"
    Service     = "orbit"
    Environment = var.environment
  }
}

# Read task definition templates
locals {
  axon_task_def = templatefile("${path.module}/task-definitions/axon.json", {
    PROJECT_NAME          = var.project_name
    AXON_ROLE_ARN         = var.axon_role_arn
    ECS_EXECUTION_ROLE_ARN = aws_iam_role.ecs_task_execution.arn
    AXON_ECR_REPO         = aws_ecr_repository.axon.repository_url
    AXON_SECRET_ARN       = var.axon_secret_arn
    AWS_REGION            = var.aws_region
  })

  orbit_task_def = templatefile("${path.module}/task-definitions/orbit.json", {
    PROJECT_NAME            = var.project_name
    ORBIT_ROLE_ARN          = var.orbit_role_arn
    ECS_EXECUTION_ROLE_ARN  = aws_iam_role.ecs_task_execution.arn
    ORBIT_ECR_REPO          = aws_ecr_repository.orbit.repository_url
    ORBIT_SECRET_ARN        = var.orbit_secret_arn
    GOVERNANCE_FUNCTION_NAME = var.governance_function_name != "" ? var.governance_function_name : "${var.project_name}-governance"
    NAMESPACE               = var.service_discovery_namespace
    AWS_REGION              = var.aws_region
  })
}

# ECS Task Definitions
resource "aws_ecs_task_definition" "axon" {
  family                   = "${var.project_name}-axon"
  task_role_arn            = var.axon_role_arn
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = local.axon_task_def

  tags = {
    Name        = "${var.project_name}-axon-task"
    Service     = "axon"
    Environment = var.environment
  }
}

resource "aws_ecs_task_definition" "orbit" {
  family                   = "${var.project_name}-orbit"
  task_role_arn            = var.orbit_role_arn
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = local.orbit_task_def

  tags = {
    Name        = "${var.project_name}-orbit-task"
    Service     = "orbit"
    Environment = var.environment
  }
}

