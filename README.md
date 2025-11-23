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
├── docs/                          # Architecture documentation
│   ├── architecture.md            # System architecture
│   ├── failure-resilience.md      # Failure and resilience plan
│   ├── security.md                # Zero-trust security model
│   └── runbook.md                 # Operations runbook
└── scripts/                       # Utility scripts
    └── setup.sh                   # Initial setup script
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

## Quick Start

### Prerequisites
- AWS CLI v2.x configured with appropriate credentials
- Terraform >= 1.5.0
- Docker >= 24.0
- kubectl (if using EKS)
- GitHub account for CI/CD

### Setup Steps

1. **Clone and Initialize**
```bash
git clone <repository-url>
cd aws-agent-runtime-zero-trust
./scripts/setup.sh
```

2. **Configure AWS Credentials**
```bash
export AWS_PROFILE=your-profile
export AWS_REGION=us-east-1
```

3. **Deploy Infrastructure**
```bash
cd infra
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

4. **Build and Deploy Services**
```bash
# Authenticate with ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build services
cd services/axon && docker build -t axon-mini-service .
cd ../orbit && docker build -t orbit-dispatcher .

# Push to ECR (handled by CI/CD in production)
```

5. **Deploy Governance Layer**
```bash
cd governance/lambda
terraform init
terraform apply
```

6. **Verify Deployment**
```bash
# Check service health
curl https://<alb-endpoint>/health

# Test governance flow
./scripts/test-governance.sh
```

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

- [Architecture Overview](docs/architecture.md)
- [Failure & Resilience Plan](docs/failure-resilience.md)
- [Zero-Trust Security Model](docs/security.md)
- [Operations Runbook](docs/runbook.md)

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
- Contact: devops@barnabus.ai
- Slack: #barnabus-devops

## License

Proprietary - Barnabus Internal Use Only

