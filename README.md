# AWS Agent Runtime - Zero Trust Architecture

## Overview
Production-grade AWS infrastructure implementing zero-trust security principles for agent runtime workloads. This project demonstrates enterprise-level DevOps practices with proper isolation, service boundaries, and runtime governance.

## Architecture Components

### Core Services
- **Axon Mini Service**: Reasoning endpoint with health monitoring
- **Orbit Dispatcher**: Service orchestrator with governed access to Axon
- **Governance Lambda**: Pre-call authorization layer (Think → Govern → Act)

### Infrastructure
- Multi-AZ VPC with public/private subnet segregation
- ECS Fargate runtime for containerized services
- AWS App Mesh for service-to-service communication
- Private ALB for internal traffic routing
- Dedicated KMS keys per service
- AWS Secrets Manager for credential management

### Security Features
- Zero-trust network architecture
- Service-specific IAM roles with strict boundaries
- No wildcard permissions
- Private-only inter-service communication
- SigV4 request signing
- Network ACLs with minimal permissions

## Project Structure

```
├── tasks/                         # Implementation tasks breakdown
│   ├── README.md                  # Task execution guide
│   ├── task-1-infrastructure.md   # Infrastructure setup
│   ├── task-2-microservices.md    # Microservices development
│   ├── task-3-governance.md       # Governance layer
│   ├── task-4-cicd.md            # CI/CD pipeline
│   ├── task-5-observability.md   # Observability setup
│   ├── task-6-security.md        # Security implementation
│   ├── task-7-documentation.md   # Documentation
│   └── test-task-*.sh            # Task validation scripts
├── infra/                         # Terraform infrastructure as code
│   ├── modules/                   # Reusable Terraform modules
│   ├── environments/              # Environment-specific configs
│   └── README.md                  # Infrastructure documentation
├── services/                      # Microservices
│   ├── axon/                      # Axon reasoning service
│   ├── orbit/                     # Orbit dispatcher service
│   └── README.md                  # Services documentation
├── governance/                    # Governance layer
│   ├── lambda/                    # Governance Lambda function
│   └── README.md                  # Governance documentation
├── cicd/                          # CI/CD pipelines
│   ├── github-actions/            # GitHub Actions workflows
│   └── README.md                  # Pipeline documentation
├── observability/                 # Monitoring and logging
│   ├── dashboards/                # CloudWatch dashboards
│   ├── alarms/                    # CloudWatch alarms
│   └── README.md                  # Observability documentation
├── docs/                          # Complete documentation suite
│   ├── architecture.md            # System architecture overview
│   ├── failure-resilience.md      # Failure handling and resilience
│   ├── runbook.md                 # Operations procedures and runbook
│   ├── setup-guide.md             # Complete setup and deployment guide
│   ├── api.md                     # API documentation and examples
│   ├── troubleshooting.md         # Common issues and solutions
│   ├── performance.md             # Performance characteristics and optimization
│   ├── security.md                # Zero-trust security model
│   └── sigv4-implementation.md    # SigV4 signing implementation
└── scripts/                       # Utility scripts
    ├── setup.sh                   # Initial project setup
    ├── setup-terraform-backend.sh # Setup S3 & DynamoDB for Terraform state
    ├── first-deploy.sh            # First infrastructure deployment
    ├── health-check.sh            # System health verification
    └── README.md                  # Scripts documentation
```

## Implementation Tasks

This project is organized into 7 sequential tasks that can be implemented and tested independently:

### Task Execution Order
1. **[Task 1: Infrastructure](./tasks/task-1-infrastructure.md)** - VPC, ECS, KMS, IAM
2. **[Task 2: Microservices](./tasks/task-2-microservices.md)** - Axon & Orbit services
3. **[Task 3: Governance](./tasks/task-3-governance.md)** - Lambda authorization layer
4. **[Task 4: CI/CD](./tasks/task-4-cicd.md)** - GitHub Actions pipelines
5. **[Task 5: Observability](./tasks/task-5-observability.md)** - Monitoring & logging
6. **[Task 6: Security](./tasks/task-6-security.md)** - Zero-trust validation
7. **[Task 7: Documentation](./tasks/task-7-documentation.md)** - Complete docs

### Task Validation
Each task includes automated testing:
```bash
cd tasks
./test-task-1.sh  # Test infrastructure
./test-task-2.sh  # Test microservices
# ... etc
```

See [Task Execution Guide](./tasks/README.md) for detailed implementation instructions.

## Setup Guide

### Prerequisites

#### AWS Account Setup
1. **Create AWS Account** or use existing account
2. **Configure AWS CLI**:
   ```bash
   aws configure
   # Enter your access key, secret key, default region (us-east-1), and output format (json)
   ```

3. **Verify Account Limits**:
   - ECS: 10 clusters, 100 services
   - Lambda: 1000 concurrent executions
   - DynamoDB: 40 read/write capacity units

#### Local Development Setup
1. **Install Required Tools**:
   ```bash
   # Terraform
   curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
   sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
   sudo apt-get update && sudo apt-get install terraform

   # AWS CLI v2
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install

   # Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh

   # Go (for local development)
   wget https://golang.org/dl/go1.21.0.linux-amd64.tar.gz
   sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
   export PATH=$PATH:/usr/local/go/bin
   ```

2. **Clone Repository**:
   ```bash
   git clone https://github.com/your-org/aws-agent-runtime-zero-trust.git
   cd aws-agent-runtime-zero-trust
   ```

3. **Initialize Project**:
   ```bash
   ./scripts/setup.sh
   ```

### Infrastructure Deployment

#### Step 1: Configure Environment
```bash
# Copy and edit environment configuration
cp .env.local.example .env.local
nano .env.local

# Required variables:
# AWS_REGION=us-east-1
# PROJECT_NAME=agent-runtime
# ENVIRONMENT=dev
```

#### Step 2: Deploy Infrastructure
```bash
cd infra

# Initialize Terraform
terraform init

# Review planned changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan
```

#### Step 3: Verify Infrastructure
```bash
# Check VPC creation
aws ec2 describe-vpcs --filters Name=tag:Name,Values=${PROJECT_NAME}-vpc

# Verify ECS cluster
aws ecs describe-clusters --clusters ${PROJECT_NAME}-cluster

# Check ECR repositories
aws ecr describe-repositories --repository-names ${PROJECT_NAME}/axon ${PROJECT_NAME}/orbit
```

### Service Deployment

#### Step 1: Build Services
```bash
# Build Axon service
cd services/axon
docker build -t axon:latest .

# Build Orbit service
cd ../orbit
docker build -t orbit:latest .
```

#### Step 2: Push Images to ECR
```bash
# Authenticate with ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Tag and push Axon
docker tag axon:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${PROJECT_NAME}/axon:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${PROJECT_NAME}/axon:latest

# Tag and push Orbit
docker tag orbit:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${PROJECT_NAME}/orbit:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${PROJECT_NAME}/orbit:latest
```

#### Step 3: Deploy Services
```bash
cd infra

# Update task definitions with new image URIs
terraform apply -target=module.ecs

# Deploy services
aws ecs update-service --cluster ${PROJECT_NAME}-cluster --service ${PROJECT_NAME}-axon --force-new-deployment
aws ecs update-service --cluster ${PROJECT_NAME}-cluster --service ${PROJECT_NAME}-orbit --force-new-deployment
```

#### Step 4: Configure Governance
```bash
cd governance/terraform

# Deploy governance infrastructure
terraform init
terraform apply

# Load default policies
cd ../scripts
python load-policies.py
```

### CI/CD Setup

#### GitHub Actions Configuration
1. **Create GitHub Repository** (if not already done)
2. **Add Secrets** to repository settings:
   ```
   AWS_REGION: us-east-1
   AWS_ECR_REGISTRY: <account-id>.dkr.ecr.us-east-1.amazonaws.com
   AWS_GITHUB_ACTIONS_ROLE: arn:aws:iam::<account-id>:role/github-actions-role
   AWS_DEPLOY_ROLE: arn:aws:iam::<account-id>:role/deploy-role
   PROJECT_NAME: agent-runtime
   ```
3. **Enable GitHub Actions** in repository settings
4. **Configure Branch Protection**:
   - Require pull request reviews
   - Require status checks (build, security, test)
   - Require branches to be up to date

#### OIDC Provider Setup
```bash
# This is handled by Terraform in infra/modules/cicd/github-oidc.tf
cd infra
terraform apply -target=module.cicd
```

### Verification

#### Health Checks
```bash
# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers --names ${PROJECT_NAME}-alb --query 'LoadBalancers[0].DNSName' --output text)

# Test health endpoints
curl -f https://${ALB_DNS}/health

# Test governance
curl -X POST https://${ALB_DNS}/dispatch \
  -H "Content-Type: application/json" \
  -d "{}"
```

#### Monitoring Setup
```bash
# Check CloudWatch dashboards
aws cloudwatch list-dashboards --query "DashboardEntries[?contains(DashboardName, \`${PROJECT_NAME}\`)]"

# Verify alarms
aws cloudwatch describe-alarms --alarm-name-prefix "${PROJECT_NAME}"

# Check log groups
aws logs describe-log-groups --log-group-name-prefix "/ecs/${PROJECT_NAME}"
```

### Troubleshooting Common Issues

#### Terraform Apply Fails
```bash
# Check AWS limits
aws service-quotas get-service-quota --service-code ecs --quota-code L-21DAFBDC

# Verify permissions
aws sts get-caller-identity

# Check Terraform state
cd infra
terraform state list
```

#### Service Deployment Fails
```bash
# Check ECS service events
aws ecs describe-services --cluster ${PROJECT_NAME}-cluster --services ${PROJECT_NAME}-axon \
  --query 'services[0].events[0:5]'

# Check task status
aws ecs list-tasks --cluster ${PROJECT_NAME}-cluster --service-name ${PROJECT_NAME}-axon
aws ecs describe-tasks --cluster ${PROJECT_NAME}-cluster --tasks <task-arn>
```

#### Image Push Fails
```bash
# Check ECR permissions
aws ecr get-authorization-token

# Verify repository exists
aws ecr describe-repositories --repository-names ${PROJECT_NAME}/axon
```

### Next Steps

1. **Configure Monitoring**: Set up alerts and notifications
2. **Security Review**: Run security audit and penetration testing
3. **Performance Testing**: Load test the system
4. **Documentation**: Complete operational runbooks
5. **Backup Strategy**: Configure automated backups

For detailed troubleshooting and advanced configuration, see the [complete setup guide](docs/setup-guide.md).

## Security Model

### Zero-Trust Principles
1. **No implicit trust**: Every request is authenticated and authorized
2. **Least privilege access**: Minimal IAM permissions per service
3. **Network segmentation**: Private subnets with controlled routing
4. **Encrypted communications**: TLS everywhere, KMS-encrypted secrets
5. **Request signing**: SigV4 signatures for service-to-service calls

### IAM Boundaries
- Each service has dedicated IAM role
- Axon cannot access Orbit's secrets
- Orbit cannot access Axon's secrets
- Governance Lambda has read-only policy access

### Network Isolation
- No public ingress to Axon or Orbit
- Services communicate through App Mesh only
- Orbit → Governance → Axon (governed flow)
- NACLs restrict traffic to specific ports/protocols

## CI/CD Pipeline

### Pipeline Stages
1. **Build**: Docker image creation
2. **Security Scan**: Trivy vulnerability scanning
3. **Test**: Unit and integration tests
4. **Deploy**: Blue-green deployment to ECS
5. **Verify**: Health checks and smoke tests
6. **Rollback**: Automatic rollback on failure

### Deployment Strategy
- Blue-green deployment for zero-downtime
- Canary releases for gradual rollout
- Automatic rollback on health check failure
- CloudWatch logs for audit trail

## Observability

### Metrics
- Service health and availability
- Request latency (p50, p95, p99)
- Governance decision latency
- Error rates and types
- Resource utilization (CPU, memory, network)

### Logging
- Structured JSON logs
- Correlation IDs for request tracing
- Centralized CloudWatch Logs
- Log retention: 30 days (configurable)

### Dashboards
- Service health overview
- Latency percentiles
- Error rate tracking
- Resource utilization
- Governance decisions

### Alerting
- Service down alerts
- High error rate (> 5%)
- High latency (p99 > 1s)
- Governance denials spike
- Resource exhaustion

## Performance Targets

| Metric | Target | Action |
|--------|--------|--------|
| p50 latency | < 100ms | Monitor |
| p95 latency | < 300ms | Investigate |
| p99 latency | < 500ms | Alert |
| Availability | 99.9% | SLA requirement |
| Error rate | < 1% | Auto-scale/alert |

## Scaling Strategy

### Horizontal Scaling
- ECS Auto Scaling based on CPU/Memory
- Target tracking: 70% CPU utilization
- Min: 2 tasks per service (HA)
- Max: 10 tasks per service

### Future GPU Support
- ECS GPU-enabled task definitions
- Dedicated GPU instance types
- Reserved capacity for predictable workloads

## Cost Optimization

- Fargate Spot for non-critical workloads
- S3 lifecycle policies for logs
- Right-sizing based on metrics
- Reserved capacity for baseline load
- Auto-scaling for burst traffic

## Incident Response

### Severity Levels
- **P0**: Service down, immediate response
- **P1**: Degraded performance, 1-hour response
- **P2**: Minor issues, 4-hour response
- **P3**: Improvements, scheduled

### Response Plan
1. Alert triggered → PagerDuty notification
2. Check dashboards for root cause
3. Review recent deployments
4. Rollback if deployment-related
5. Scale up if capacity issue
6. Post-incident review (PIR)

## Multi-Tenancy

### Tenant Isolation
- Separate VPCs per major tenant (future)
- Service tags for tenant identification
- Resource quotas per tenant
- Governance rules per tenant

## Documentation

### Architecture & Design
- [System Architecture](docs/architecture.md) - High-level system overview and component details
- [API Documentation](docs/api.md) - Complete API reference with examples in Python, JavaScript, and Go
- [Performance Characteristics](docs/performance.md) - Benchmarks, optimization guidelines, and monitoring

### Operations & Maintenance
- [Setup Guide](docs/setup-guide.md) - Complete deployment and configuration instructions
- [Operations Runbook](docs/runbook.md) - Daily operations, incident response, and maintenance procedures
- [Failure & Resilience Plan](docs/failure-resilience.md) - Failure scenarios, recovery procedures, and resilience strategies
- [Troubleshooting Guide](docs/troubleshooting.md) - Common issues, diagnostic tools, and solutions

### Security & Compliance
- [Zero-Trust Security Model](docs/security.md) - Security architecture and threat mitigation
- [SigV4 Implementation](docs/sigv4-implementation.md) - AWS signature version 4 signing details

### Task Documentation
- [Task 1: Infrastructure](tasks/task-1-infrastructure.md) - VPC, ECS, and networking setup
- [Task 2: Microservices](tasks/task-2-microservices.md) - Axon and Orbit service development
- [Task 3: Governance](tasks/task-3-governance.md) - Authorization and policy layer
- [Task 4: CI/CD](tasks/task-4-cicd.md) - Pipeline and automation setup
- [Task 5: Observability](tasks/task-5-observability.md) - Monitoring and logging implementation
- [Task 6: Security](tasks/task-6-security.md) - Zero-trust validation and hardening
- [Task 7: Documentation](tasks/task-7-documentation.md) - Complete documentation suite

## Contributing

1. Create feature branch
2. Make changes with tests
3. Submit PR with description
4. Pass CI/CD checks
5. Get review approval
6. Merge to main

## Support

For questions or issues:
- Create GitHub issue
- Contact: hatef.rostamkhani@gmail.com

## License

MIT License

Copyright (c) 2024 AWS Agent Runtime Zero Trust

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

