# Null resource to ensure listener rule is created before ECS service
# This ensures the target group is associated with the ALB via the listener rule
resource "null_resource" "axon_listener_rule_ready" {
  triggers = {
    listener_rule_arn = var.axon_listener_rule_arn
  }
}

resource "aws_ecs_service" "axon" {
  name            = "${var.project_name}-axon"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.axon.arn
  desired_count   = 0 # Start with 0, will be scaled up after images are deployed
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [var.axon_security_group_id]
    subnets          = var.axon_runtime_subnet_ids
    assign_public_ip = false
  }

  service_registries {
    registry_arn = var.axon_service_discovery_arn
  }

  load_balancer {
    target_group_arn = var.axon_target_group_arn
    container_name   = "axon"
    container_port   = 80
  }

  deployment_controller {
    type = "ECS"
  }

  tags = {
    Name        = "${var.project_name}-axon-service"
    Service     = "axon"
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution,
    null_resource.axon_listener_rule_ready
  ]
}

# Null resource to ensure listener rule is created before ECS service
# This ensures the target group is associated with the ALB via the listener rule
resource "null_resource" "orbit_listener_rule_ready" {
  triggers = {
    listener_rule_arn = var.orbit_listener_rule_arn
  }
}

resource "aws_ecs_service" "orbit" {
  name            = "${var.project_name}-orbit"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.orbit.arn
  desired_count   = 0 # Start with 0, will be scaled up after images are deployed
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [var.orbit_security_group_id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  service_registries {
    registry_arn = var.orbit_service_discovery_arn
  }

  load_balancer {
    target_group_arn = var.orbit_target_group_arn
    container_name   = "orbit"
    container_port   = 80
  }

  deployment_controller {
    type = "ECS"
  }

  tags = {
    Name        = "${var.project_name}-orbit-service"
    Service     = "orbit"
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution,
    null_resource.orbit_listener_rule_ready
  ]
}

