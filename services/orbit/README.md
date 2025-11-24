# Orbit Service

Orbit is the dispatcher service in the AWS Agent Runtime Zero Trust architecture. It orchestrates calls to the Axon service after governance checks.

## Overview

Orbit is a microservice that:
- Dispatches requests to Axon after governance authorization
- Integrates with AWS Lambda for governance checks
- Implements circuit breaker pattern for resilience
- Uses SigV4 signing for secure service-to-service communication
- Implements retry logic with exponential backoff

## Architecture

- **Language**: Go 1.18+
- **Framework**: Gorilla Mux
- **Logging**: Zerolog (structured JSON)
- **AWS SDK**: AWS SDK for Go v1
- **Resilience**: Circuit breaker, retry with exponential backoff

## Endpoints

### GET /health
Returns the health status of the service.

**Response:**
```json
{
  "status": "healthy",
  "service": "orbit",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

### POST /dispatch
Dispatches a request to Axon after governance check.

**Response (Success):**
```json
{
  "status": "success",
  "message": "Axon heartbeat OK",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

**Response (Governance Denied):**
```json
{
  "status": "denied",
  "reason": "Policy violation",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

## Environment Variables

- `AWS_REGION`: AWS region (default: us-east-1)
- `PORT`: Service port (default: 80)
- `GOVERNANCE_FUNCTION_NAME`: Name of the governance Lambda function
- `AXON_SERVICE_URL`: URL of the Axon service (default: http://axon/reason)
- `ORBIT_SECRET_ARN`: ARN of the AWS Secrets Manager secret

## Local Development

### Prerequisites
- Go 1.18 or later
- Docker (for containerized builds)
- AWS credentials configured
- Governance Lambda function deployed

### Build and Run

```bash
# Install dependencies
go mod tidy

# Run locally
go run main.go

# Build binary
go build -o orbit .

# Run tests
go test ./tests/unit/ -v
go test ./tests/integration/ -v
```

### Docker Build

```bash
# Build image
docker build -t orbit-service .

# Run container
docker run -p 8080:80 \
  -e AWS_REGION=us-east-1 \
  -e GOVERNANCE_FUNCTION_NAME=agent-runtime-governance \
  -e AXON_SERVICE_URL=http://axon/reason \
  orbit-service
```

## Testing

### Unit Tests
```bash
go test ./tests/unit/ -v
```

### Integration Tests
```bash
go test ./tests/integration/ -v
```

### Health Check
```bash
curl http://localhost:80/health
```

### Dispatch Request
```bash
curl -X POST http://localhost:80/dispatch
```

## Resilience Features

### Circuit Breaker
- Opens after 5 consecutive failures
- Resets after 30 seconds
- Prevents cascading failures

### Retry Logic
- Maximum 3 retry attempts
- Exponential backoff: 100ms, 200ms, 400ms
- Jitter added to prevent thundering herd

### SigV4 Signing
- All requests to Axon are signed with AWS SigV4
- Ensures secure service-to-service communication
- Uses IAM credentials for authentication

## Deployment

The service is deployed to AWS ECS Fargate using:
- Multi-stage Docker builds for minimal image size
- Non-root user for security
- CloudWatch Logs for centralized logging
- Service discovery for inter-service communication

## Security

- Governance checks required before Axon calls
- SigV4 signing for all Axon requests
- Secrets loaded from AWS Secrets Manager
- Correlation IDs propagated for tracing
- Non-root user in Docker container

## Monitoring

Logs are sent to CloudWatch Logs group: `/ecs/{project_name}-orbit`

Log format (JSON):
```json
{
  "level": "info",
  "service": "orbit",
  "correlation_id": "...",
  "message": "...",
  "time": "..."
}
```

## Flow

1. Request arrives at `/dispatch`
2. Governance check via Lambda function
3. If denied, return 403 with reason
4. If allowed, call Axon service with SigV4 signing
5. Return Axon response or error

