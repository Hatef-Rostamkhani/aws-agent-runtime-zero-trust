# Axon Virtual Node
resource "aws_appmesh_virtual_node" "axon" {
  name      = "${var.project_name}-axon-vnode"
  mesh_name = aws_appmesh_mesh.main.id

  spec {
    listener {
      port_mapping {
        port     = 8080
        protocol = "http"
      }

      health_check {
        protocol            = "http"
        path                = "/health"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout_millis      = 2000
        interval_millis     = 5000
      }
    }

    service_discovery {
      aws_cloud_map {
        service_name   = aws_service_discovery_service.axon.name
        namespace_name = aws_service_discovery_private_dns_namespace.main.name
      }
    }
  }

  tags = {
    Name = "${var.project_name}-axon-vnode"
  }
}

# Orbit Virtual Node
resource "aws_appmesh_virtual_node" "orbit" {
  name      = "${var.project_name}-orbit-vnode"
  mesh_name = aws_appmesh_mesh.main.id

  spec {
    backend {
      virtual_service {
        virtual_service_name = aws_appmesh_virtual_service.axon.name
      }
    }

    listener {
      port_mapping {
        port     = 8080
        protocol = "http"
      }

      health_check {
        protocol            = "http"
        path                = "/health"
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout_millis      = 2000
        interval_millis     = 5000
      }
    }

    service_discovery {
      aws_cloud_map {
        service_name   = aws_service_discovery_service.orbit.name
        namespace_name = aws_service_discovery_private_dns_namespace.main.name
      }
    }
  }

  tags = {
    Name = "${var.project_name}-orbit-vnode"
  }
}

# Governance Virtual Node
resource "aws_appmesh_virtual_node" "governance" {
  name      = "${var.project_name}-governance-vnode"
  mesh_name = aws_appmesh_mesh.main.id

  spec {
    listener {
      port_mapping {
        port     = 443
        protocol = "http"
      }
    }

    service_discovery {
      aws_cloud_map {
        service_name   = aws_service_discovery_service.governance.name
        namespace_name = aws_service_discovery_private_dns_namespace.main.name
      }
    }
  }

  tags = {
    Name = "${var.project_name}-governance-vnode"
  }
}

