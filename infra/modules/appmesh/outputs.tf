output "mesh_name" {
  description = "App Mesh name"
  value       = aws_appmesh_mesh.main.name
}

output "mesh_arn" {
  description = "App Mesh ARN"
  value       = aws_appmesh_mesh.main.arn
}

output "service_discovery_namespace" {
  description = "Service discovery namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "service_discovery_namespace_id" {
  description = "Service discovery namespace ID"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

