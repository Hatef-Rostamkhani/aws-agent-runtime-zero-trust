# Axon Service

Axon is the reasoning service in the AWS Agent Runtime Zero Trust architecture. It provides health monitoring and reasoning endpoints.

## Overview

Axon is a lightweight microservice that:
- Provides health check endpoints for monitoring
- Implements reasoning logic (currently returns heartbeat)
- Integrates with AWS Secrets Manager for secure configuration
- Uses structured JSON logging for observability
- Supports correlation ID propagation for request tracing

## Architecture

- **Language**: Go 1.18+
- **Framework**: Gorilla Mux
- **Logging**: Zerolog (structured JSON)
- **AWS SDK**: AWS SDK for Go v1

## Endpoints

### GET /health
Returns the health status of the service.

**Response:**
```json
{
  "status": "healthy",
  "service": "axon",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

### GET /reason
Returns a reasoning heartbeat message.

**Response:**
```json
{
  "message": "Axon heartbeat OK",
  "service": "axon",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## Environment Variables

- `AWS_REGION`: AWS region (default: us-east-1)
- `PORT`: Service port (default: 80)
- `AXON_SECRET_ARN`: ARN of the AWS Secrets Manager secret containing service configuration

## Local Development

### Prerequisites
- Go 1.18 or later
- Docker (for containerized builds)
- AWS credentials configured (for secrets access)

### Build and Run

```bash
# Install dependencies
go mod tidy

# Run locally
go run main.go

# Build binary
go build -o axon .

# Run tests
go test ./tests/unit/ -v
```

### Docker Build

```bash
# Build image
docker build -t axon-service .

# Run container
docker run -p 8080:80 \
  -e AWS_REGION=us-east-1 \
  -e AXON_SECRET_ARN=arn:aws:secretsmanager:... \
  axon-service
```

## Testing

### Unit Tests
```bash
go test ./tests/unit/ -v
```

### Health Check
```bash
curl http://localhost:80/health
```

### Reason Endpoint
```bash
curl http://localhost:80/reason
```

## Deployment

The service is deployed to AWS ECS Fargate using:
- Multi-stage Docker builds for minimal image size
- Non-root user for security
- CloudWatch Logs for centralized logging
- Service discovery for inter-service communication

## Security

- Secrets are loaded from AWS Secrets Manager at startup
- All logs are structured JSON for CloudWatch compatibility
- Correlation IDs are propagated for request tracing
- Non-root user in Docker container

## Monitoring

Logs are sent to CloudWatch Logs group: `/ecs/{project_name}-axon`

Log format (JSON):
```json
{
  "level": "info",
  "service": "axon",
  "correlation_id": "...",
  "message": "...",
  "time": "..."
}
```

