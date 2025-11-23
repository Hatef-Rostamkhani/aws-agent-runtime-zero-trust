resource "aws_appmesh_mesh" "main" {
  name = "${var.project_name}-mesh"

  spec {
    egress_filter {
      type = "ALLOW_ALL"
    }
  }

  tags = {
    Name = "${var.project_name}-mesh"
  }
}

