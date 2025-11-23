output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.main.arn
}

output "axon_repository_url" {
  description = "Axon ECR repository URL"
  value       = aws_ecr_repository.axon.repository_url
}

output "orbit_repository_url" {
  description = "Orbit ECR repository URL"
  value       = aws_ecr_repository.orbit.repository_url
}

output "task_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

