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

output "axon_service_discovery_arn" {
  description = "Axon service discovery ARN"
  value       = aws_service_discovery_service.axon.arn
}

output "orbit_service_discovery_arn" {
  description = "Orbit service discovery ARN"
  value       = aws_service_discovery_service.orbit.arn
}

