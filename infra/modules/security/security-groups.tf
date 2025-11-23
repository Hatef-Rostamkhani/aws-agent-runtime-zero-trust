# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Axon Service Security Group
resource "aws_security_group" "axon" {
  name_prefix = "${var.project_name}-axon-"
  vpc_id      = var.vpc_id

  # No inbound rules - only through App Mesh

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-axon-sg"
  }
}

# Orbit Service Security Group
resource "aws_security_group" "orbit" {
  name_prefix = "${var.project_name}-orbit-"
  vpc_id      = var.vpc_id

  # No inbound rules - only through App Mesh

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-orbit-sg"
  }
}

# Governance Lambda Security Group
resource "aws_security_group" "governance" {
  name_prefix = "${var.project_name}-governance-"
  vpc_id      = var.vpc_id

  # Lambda can be invoked via API Gateway, no inbound SG rules needed

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-governance-sg"
  }
}

