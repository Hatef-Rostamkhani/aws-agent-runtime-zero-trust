resource "aws_appmesh_virtual_router" "axon" {
  name      = "${var.project_name}-axon-vrouter"
  mesh_name = aws_appmesh_mesh.main.id

  spec {
    listener {
      port_mapping {
        port     = 80
        protocol = "http"
      }
    }
  }

  tags = {
    Name = "${var.project_name}-axon-vrouter"
  }
}

resource "aws_appmesh_route" "axon" {
  name                = "${var.project_name}-axon-route"
  mesh_name           = aws_appmesh_mesh.main.id
  virtual_router_name = aws_appmesh_virtual_router.axon.name

  spec {
    http_route {
      match {
        prefix = "/"
      }

      action {
        weighted_target {
          virtual_node = aws_appmesh_virtual_node.axon.name
          weight       = 100
        }
      }
    }
  }

  tags = {
    Name = "${var.project_name}-axon-route"
  }
}

resource "aws_appmesh_virtual_service" "axon" {
  name      = "${var.project_name}-axon.${aws_service_discovery_private_dns_namespace.main.name}"
  mesh_name = aws_appmesh_mesh.main.id

  spec {
    provider {
      virtual_router {
        virtual_router_name = aws_appmesh_virtual_router.axon.name
      }
    }
  }

  tags = {
    Name = "${var.project_name}-axon-vs"
  }
}

resource "aws_appmesh_virtual_service" "orbit_governance" {
  name      = "${var.project_name}-governance.${aws_service_discovery_private_dns_namespace.main.name}"
  mesh_name = aws_appmesh_mesh.main.id

  spec {
    provider {
      virtual_node {
        virtual_node_name = aws_appmesh_virtual_node.governance.name
      }
    }
  }

  tags = {
    Name = "${var.project_name}-orbit-governance-vs"
  }
}

