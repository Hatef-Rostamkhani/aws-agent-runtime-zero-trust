# Task 1: Infrastructure Setup

**Duration:** 8-12 hours
**Priority:** CRITICAL - Must complete first
**Dependencies:** None

## Overview

Build the complete AWS infrastructure using Terraform, including VPC, networking, ECS cluster, secrets management, and IAM boundaries.

## Objectives

- [ ] Create multi-AZ VPC with proper subnet segregation
- [ ] Implement restrictive NACLs and security groups
- [ ] Setup ECS Fargate cluster with ECR repositories
- [ ] Configure AWS App Mesh for service communication
- [ ] Setup KMS keys and Secrets Manager per service
- [ ] Create IAM roles with strict boundaries

## Prerequisites

- AWS CLI configured with admin access
- Terraform >= 1.5.0 installed
- AWS account with appropriate limits
- Understanding of VPC networking

## File Structure

```
infra/
├── main.tf                    # Root module
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example variables
├── modules/
│   ├── networking/
│   │   ├── vpc.tf
│   │   ├── subnets.tf
│   │   ├── routing.tf
│   │   ├── nacls.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security/
│   │   ├── security-groups.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ecs/
│   │   ├── cluster.tf
│   │   ├── repositories.tf
│   │   ├── iam.tf
│   │   ├── cloudwatch.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── appmesh/
│   │   ├── mesh.tf
│   │   ├── virtual-nodes.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── alb/
│   │   ├── alb.tf
│   │   ├── target-groups.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── kms/
│   │   ├── keys.tf
│   │   ├── policies.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── secrets/
│   │   ├── secrets.tf
│   │   ├── iam-policies.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── iam/
│       ├── boundaries.tf
│       ├── axon-role.tf
│       ├── orbit-role.tf
│       ├── variables.tf
│       └── outputs.tf
```

## Implementation Steps

### Step 1.1: Network Foundation (2-3 hours)

Create the VPC and subnet structure.

**File: infra/modules/networking/vpc.tf**

```hcl
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}
```

**Test Step 1.1:**

```bash
cd infra/modules/networking
terraform init
terraform validate
terraform plan

# If validation passes:
cd ../../
terraform init
terraform plan -target=module.networking
```

### Step 1.2: Subnets (1-2 hours)

**File: infra/modules/networking/subnets.tf**

```hcl
# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  }
}

# Private Subnets (General)
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 3)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-${var.availability_zones[count.index]}"
    Tier = "private"
  }
}

# Axon Runtime Subnets (Isolated)
resource "aws_subnet" "axon_runtime" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 6)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-axon-runtime-${var.availability_zones[count.index]}"
    Tier = "axon-runtime"
  }
}
```

**File: infra/modules/networking/routing.tf**

```hcl
# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Axon Runtime Route Table (No internet access)
resource "aws_route_table" "axon_runtime" {
  vpc_id = aws_vpc.main.id

  # No default route to internet - fully isolated

  tags = {
    Name = "${var.project_name}-axon-runtime-rt"
  }
}

resource "aws_route_table_association" "axon_runtime" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.axon_runtime[count.index].id
  route_table_id = aws_route_table.axon_runtime.id
}
```

**Test Step 1.2:**

```bash
cd infra
terraform plan -target=module.networking
terraform apply -target=module.networking

# Verify subnets:
aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID --query 'Subnets[*].{ID:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock,Tags:Tags}'
```

### Step 1.3: Network Security (1-2 hours)

**File: infra/modules/networking/nacls.tf**

```hcl
# Public Subnet NACL - Restrictive
resource "aws_network_acl" "public" {
  vpc_id = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # Allow inbound HTTPS from anywhere (for ALB)
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow inbound HTTP from anywhere (for redirects)
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Allow inbound ephemeral ports from anywhere
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow all outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.project_name}-public-nacl"
  }
}

# Private Subnet NACL - Very restrictive
resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Allow inbound traffic only from VPC
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow all outbound traffic
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.project_name}-private-nacl"
  }
}

# Axon Runtime NACL - Most restrictive
resource "aws_network_acl" "axon_runtime" {
  vpc_id = aws_vpc.main.id
  subnet_ids = aws_subnet.axon_runtime[*].id

  # Allow inbound traffic only from private subnets (for Orbit)
  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  # Allow outbound traffic only to private subnets
  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${var.project_name}-axon-runtime-nacl"
  }
}
```

**File: infra/modules/security/security-groups.tf**

```hcl
# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = aws_vpc.main.id

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
  vpc_id      = aws_vpc.main.id

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
  vpc_id      = aws_vpc.main.id

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
  vpc_id      = aws_vpc.main.id

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
```

**Test Step 1.3:**

```bash
# Test security groups
cd infra
terraform apply -target=module.networking -target=module.security

# Verify NACLs
aws ec2 describe-network-acls --filters Name=vpc-id,Values=$VPC_ID

# Test connectivity (should fail for axon-runtime to internet)
aws ec2 run-instances --image-id ami-12345678 --count 1 --instance-type t2.micro --subnet-id $AXON_SUBNET_ID --security-group-ids $AXON_SG_ID
```

### Step 1.4: ECS Fargate Cluster (1-2 hours)

**File: infra/modules/ecs/cluster.tf**

```hcl
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}
```

**File: infra/modules/ecs/repositories.tf**

```hcl
resource "aws_ecr_repository" "axon" {
  name                 = "${var.project_name}/axon"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-axon-repo"
  }
}

resource "aws_ecr_repository" "orbit" {
  name                 = "${var.project_name}/orbit"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-orbit-repo"
  }
}

resource "aws_ecr_lifecycle_policy" "axon" {
  repository = aws_ecr_repository.axon.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "orbit" {
  repository = aws_ecr_repository.orbit.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
```

**File: infra/modules/ecs/iam.tf**

```hcl
# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# CloudWatch Logs policy for task execution
resource "aws_iam_role_policy" "ecs_task_execution_logs" {
  name = "${var.project_name}-ecs-task-execution-logs"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}
```

**Test Step 1.4:**

```bash
cd infra
terraform apply -target=module.ecs

# Verify cluster
aws ecs describe-clusters --cluster $CLUSTER_NAME

# Verify repositories
aws ecr describe-repositories --repository-names ${PROJECT_NAME}/axon ${PROJECT_NAME}/orbit
```

### Step 1.5: Service Mesh Setup (2-3 hours)

**File: infra/modules/appmesh/mesh.tf**

```hcl
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
```

**File: infra/modules/appmesh/virtual-nodes.tf**

```hcl
# Axon Virtual Node
resource "aws_appmesh_virtual_node" "axon" {
  name      = "${var.project_name}-axon-vnode"
  mesh_name = aws_appmesh_mesh.main.id

  spec {
    backend {
      virtual_service {
        virtual_service_name = aws_appmesh_virtual_service.orbit_governance.name
      }
    }

    listener {
      port_mapping {
        port     = 80
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
        service_name   = "axon"
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

    backend {
      virtual_service {
        virtual_service_name = aws_appmesh_virtual_service.orbit_governance.name
      }
    }

    listener {
      port_mapping {
        port     = 80
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
        service_name   = "orbit"
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
        service_name   = "governance"
        namespace_name = aws_service_discovery_private_dns_namespace.main.name
      }
    }
  }

  tags = {
    Name = "${var.project_name}-governance-vnode"
  }
}
```

**File: infra/modules/appmesh/virtual-router.tf**

```hcl
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
```

**Test Step 1.5:**

```bash
cd infra
terraform apply -target=module.appmesh

# Verify mesh
aws appmesh describe-mesh --mesh-name $MESH_NAME

# Verify virtual nodes
aws appmesh list-virtual-nodes --mesh-name $MESH_NAME
```

### Step 1.6: ALB Configuration (1 hour)

**File: infra/modules/alb/alb.tf**

```hcl
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.private[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}
```

**Test Step 1.6:**

```bash
cd infra
terraform apply -target=module.alb

# Verify ALB
aws elbv2 describe-load-balancers --names $ALB_NAME
```

### Step 1.7: Secrets and KMS (2 hours)

**File: infra/modules/kms/keys.tf**

```hcl
resource "aws_kms_key" "axon" {
  description             = "KMS key for Axon service encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.axon_kms_policy.json

  tags = {
    Name = "${var.project_name}-axon-key"
  }
}

resource "aws_kms_key" "orbit" {
  description             = "KMS key for Orbit service encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.orbit_kms_policy.json

  tags = {
    Name = "${var.project_name}-orbit-key"
  }
}

resource "aws_kms_alias" "axon" {
  name          = "alias/${var.project_name}-axon"
  target_key_id = aws_kms_key.axon.key_id
}

resource "aws_kms_alias" "orbit" {
  name          = "alias/${var.project_name}-orbit"
  target_key_id = aws_kms_key.orbit.key_id
}
```

**File: infra/modules/kms/policies.tf**

```hcl
data "aws_iam_policy_document" "axon_kms_policy" {
  statement {
    sid = "Enable IAM User Permissions"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid = "Allow Axon Role"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.axon.arn]
    }
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]
    resources = ["*"]
  }

  # Deny Orbit access to Axon's key
  statement {
    sid    = "Deny Orbit Role"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.orbit.arn]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "orbit_kms_policy" {
  statement {
    sid = "Enable IAM User Permissions"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid = "Allow Orbit Role"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.orbit.arn]
    }
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]
    resources = ["*"]
  }

  # Deny Axon access to Orbit's key
  statement {
    sid    = "Deny Axon Role"
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.axon.arn]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }
}
```

**File: infra/modules/secrets/secrets.tf**

```hcl
resource "aws_secretsmanager_secret" "axon" {
  name                    = "${var.project_name}/axon"
  description             = "Secrets for Axon service"
  kms_key_id              = aws_kms_key.axon.id
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-axon-secret"
  }
}

resource "aws_secretsmanager_secret_version" "axon" {
  secret_id = aws_secretsmanager_secret.axon.id
  secret_string = jsonencode({
    database_url = "placeholder"
    api_key      = "placeholder"
  })
}

resource "aws_secretsmanager_secret" "orbit" {
  name                    = "${var.project_name}/orbit"
  description             = "Secrets for Orbit service"
  kms_key_id              = aws_kms_key.orbit.id
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-orbit-secret"
  }
}

resource "aws_secretsmanager_secret_version" "orbit" {
  secret_id = aws_secretsmanager_secret.orbit.id
  secret_string = jsonencode({
    database_url = "placeholder"
    api_key      = "placeholder"
  })
}
```

**Test Step 1.7:**

```bash
cd infra
terraform apply -target=module.kms -target=module.secrets

# Test key isolation
aws kms describe-key --key-id alias/${PROJECT_NAME}-axon --query KeyMetadata.Arn

# Verify Orbit cannot access Axon's key (should fail)
aws kms describe-key --key-id alias/${PROJECT_NAME}-axon --profile orbit-role
```

### Step 1.8: IAM Roles with Boundaries (2 hours)

**File: infra/modules/iam/boundaries.tf**

```hcl
resource "aws_iam_policy" "axon_boundary" {
  name = "${var.project_name}-axon-boundary"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = aws_kms_key.axon.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.axon.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/ecs/${var.project_name}-axon:*"
      }
    ]
  })
}

resource "aws_iam_policy" "orbit_boundary" {
  name = "${var.project_name}-orbit-boundary"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = aws_kms_key.orbit.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.orbit.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/ecs/${var.project_name}-orbit:*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.governance.arn
      }
    ]
  })
}
```

**File: infra/modules/iam/axon-role.tf**

```hcl
resource "aws_iam_role" "axon" {
  name                 = "${var.project_name}-axon-role"
  permissions_boundary = aws_iam_policy.axon_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-axon-role"
  }
}

resource "aws_iam_role_policy_attachment" "axon_execution" {
  role       = aws_iam_role.axon.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
```

**File: infra/modules/iam/orbit-role.tf**

```hcl
resource "aws_iam_role" "orbit" {
  name                 = "${var.project_name}-orbit-role"
  permissions_boundary = aws_iam_policy.orbit_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-orbit-role"
  }
}

resource "aws_iam_role_policy_attachment" "orbit_execution" {
  role       = aws_iam_role.orbit.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
```

**Test Step 1.8:**

```bash
cd infra
terraform apply -target=module.iam

# Test role boundaries
aws sts assume-role --role-arn $AXON_ROLE_ARN --role-session-name test

# Verify Axon cannot access Orbit's secrets (should fail)
aws secretsmanager get-secret-value --secret-id $ORBIT_SECRET_ARN --profile axon-role

# Verify Orbit cannot access Axon's secrets (should fail)
aws secretsmanager get-secret-value --secret-id $AXON_SECRET_ARN --profile orbit-role
```

## Acceptance Criteria

- [ ] VPC created with 9 subnets (3 public, 3 private, 3 axon-runtime)
- [ ] NACLs configured with deny-by-default rules
- [ ] Security groups have no wildcard ingress rules
- [ ] ECS cluster created with container insights enabled
- [ ] ECR repositories created with scanning enabled
- [ ] App Mesh configured with virtual nodes and services
- [ ] KMS keys created with isolated access policies
- [ ] Secrets Manager secrets created and encrypted
- [ ] IAM roles created with permission boundaries
- [ ] Cross-service access denied at IAM level

## Rollback Procedure

If infrastructure deployment fails:

```bash
cd infra
terraform destroy -target=module.iam
terraform destroy -target=module.secrets
terraform destroy -target=module.kms
terraform destroy -target=module.appmesh
terraform destroy -target=module.alb
terraform destroy -target=module.ecs
terraform destroy -target=module.security
terraform destroy -target=module.networking
```

## Testing Script

Create `tasks/test-task-1.sh`:

```bash
#!/bin/bash
set -e

echo "Testing Task 1: Infrastructure Setup"

# Check VPC
VPC_COUNT=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=${PROJECT_NAME}-vpc --query 'length(Vpcs)')
if [ "$VPC_COUNT" -eq 0 ]; then
    echo "❌ VPC not found"
    exit 1
fi
echo "✅ VPC created"

# Check subnets
SUBNET_COUNT=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID --query 'length(Subnets)')
if [ "$SUBNET_COUNT" -ne 9 ]; then
    echo "❌ Expected 9 subnets, found $SUBNET_COUNT"
    exit 1
fi
echo "✅ All subnets created"

# Check ECS cluster
CLUSTER_EXISTS=$(aws ecs describe-clusters --clusters ${PROJECT_NAME}-cluster --query 'clusters[0].status')
if [ "$CLUSTER_EXISTS" != "\"ACTIVE\"" ]; then
    echo "❌ ECS cluster not active"
    exit 1
fi
echo "✅ ECS cluster active"

# Check ECR repositories
REPO_COUNT=$(aws ecr describe-repositories --repository-names ${PROJECT_NAME}/axon ${PROJECT_NAME}/orbit --query 'length(repositories)' 2>/dev/null || echo 0)
if [ "$REPO_COUNT" -ne 2 ]; then
    echo "❌ ECR repositories not found"
    exit 1
fi
echo "✅ ECR repositories created"

# Check KMS keys
AXON_KEY=$(aws kms describe-key --key-id alias/${PROJECT_NAME}-axon --query 'KeyMetadata.KeyState' 2>/dev/null || echo "DISABLED")
if [ "$AXON_KEY" != "\"Enabled\"" ]; then
    echo "❌ Axon KMS key not enabled"
    exit 1
fi
echo "✅ KMS keys configured"

echo ""
echo "🎉 Task 1 Infrastructure Setup: PASSED"
```
