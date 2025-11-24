# Microservices

This directory contains the microservices for the AWS Agent Runtime Zero Trust architecture.

## Services

### Axon
The reasoning service that provides health monitoring and reasoning endpoints.

- **Location**: `axon/`
- **Port**: 80
- **Endpoints**: `/health`, `/reason`
- **Documentation**: [axon/README.md](./axon/README.md)

### Orbit
The dispatcher service that orchestrates calls to Axon after governance checks.

- **Location**: `orbit/`
- **Port**: 80
- **Endpoints**: `/health`, `/dispatch`
- **Documentation**: [orbit/README.md](./orbit/README.md)

## Architecture

Both services are:
- Written in Go 1.18+
- Containerized with Docker
- Deployed to AWS ECS Fargate
- Use structured JSON logging (Zerolog)
- Support correlation ID propagation
- Integrate with AWS Secrets Manager

## Development

### Prerequisites
- Go 1.18 or later
- Docker
- AWS CLI configured
- Terraform (for infrastructure)

### Building Services

```bash
# Build Axon
cd axon
go mod tidy
go build -o axon .

# Build Orbit
cd ../orbit
go mod tidy
go build -o orbit .
```

### Running Tests

```bash
# Axon tests
cd axon
go test ./tests/unit/ -v

# Orbit tests
cd ../orbit
go test ./tests/unit/ -v
go test ./tests/integration/ -v
```

### Docker Builds

```bash
# Build Axon image
cd axon
docker build -t axon-service .

# Build Orbit image
cd ../orbit
docker build -t orbit-service .
```

## Deployment

Services are deployed via:
1. Docker images pushed to ECR
2. ECS task definitions created via Terraform
3. ECS services deployed with auto-scaling
4. Service discovery configured for inter-service communication

See [../infra/README.md](../infra/README.md) for infrastructure details.

## Communication Flow

```
Client → Orbit → Governance Lambda → Axon
                ↓ (if allowed)
                Axon → Response
```

## Security

- Zero-trust network architecture
- SigV4 signing for service-to-service calls
- IAM roles with permission boundaries
- Secrets encrypted with KMS
- Private subnets only

## Observability

- Structured JSON logs to CloudWatch
- Correlation IDs for request tracing
- Health check endpoints
- CloudWatch metrics and alarms

