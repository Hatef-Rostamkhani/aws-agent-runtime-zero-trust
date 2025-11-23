# Task 2: Microservices Development

**Duration:** 6-8 hours
**Priority:** High
**Dependencies:** Task 1 (Infrastructure)

## Overview

Develop and containerize two microservices: Axon (reasoning service) and Orbit (dispatcher service) with proper observability, security, and inter-service communication.

## Objectives

- [ ] Axon service with health and reasoning endpoints
- [ ] Orbit service with dispatch and governance integration
- [ ] Structured JSON logging with correlation IDs
- [ ] AWS SDK integration for secrets and KMS
- [ ] SigV4 request signing for secure communication
- [ ] Circuit breaker and retry patterns
- [ ] Multi-stage Docker builds with optimization
- [ ] Comprehensive unit and integration tests

## Prerequisites

- [ ] Task 1 infrastructure deployed
- [ ] Docker installed and running
- [ ] Go/Python/Node.js development environment
- [ ] AWS CLI configured
- [ ] ECR repositories accessible

## File Structure

```
services/
├── axon/
│   ├── main.go (or main.py)
│   ├── handlers/
│   │   ├── health.go
│   │   └── reason.go
│   ├── middleware/
│   │   ├── logging.go
│   │   └── correlation.go
│   ├── Dockerfile
│   ├── requirements.txt (or go.mod)
│   ├── tests/
│   │   ├── unit/
│   │   └── integration/
│   └── README.md
├── orbit/
│   ├── main.go (or main.py)
│   ├── handlers/
│   │   ├── health.go
│   │   └── dispatch.go
│   ├── clients/
│   │   ├── axon.go
│   │   └── governance.go
│   ├── middleware/
│   │   ├── logging.go
│   │   └── correlation.go
│   ├── Dockerfile
│   ├── requirements.txt (or go.mod)
│   ├── tests/
│   │   ├── unit/
│   │   └── integration/
│   └── README.md
└── README.md
```

## Implementation Steps

### Step 2.1: Axon Service Development (2-3 hours)

Create the Axon reasoning service with health monitoring.

**File: services/axon/main.go** (Go implementation)

```go
package main

import (
    "context"
    "encoding/json"
    "log"
    "net/http"
    "os"
    "time"

    "github.com/aws/aws-sdk-go/aws"
    "github.com/aws/aws-sdk-go/aws/session"
    "github.com/aws/aws-sdk-go/service/secretsmanager"
    "github.com/gorilla/mux"
)

type AxonService struct {
    secrets *secretsmanager.SecretsManager
    logger  *log.Logger
}

type HealthResponse struct {
    Status    string    `json:"status"`
    Service   string    `json:"service"`
    Timestamp time.Time `json:"timestamp"`
}

type ReasonResponse struct {
    Message   string    `json:"message"`
    Service   string    `json:"service"`
    Timestamp time.Time `json:"timestamp"`
}

func main() {
    // Initialize AWS session
    sess, err := session.NewSession(&aws.Config{
        Region: aws.String(os.Getenv("AWS_REGION")),
    })
    if err != nil {
        log.Fatalf("Failed to create AWS session: %v", err)
    }

    service := &AxonService{
        secrets: secretsmanager.New(sess),
        logger:  log.New(os.Stdout, "[AXON] ", log.LstdFlags),
    }

    // Load secrets
    if err := service.loadSecrets(); err != nil {
        log.Fatalf("Failed to load secrets: %v", err)
    }

    router := mux.NewRouter()

    // Add middleware
    router.Use(service.correlationMiddleware)
    router.Use(service.loggingMiddleware)

    // Routes
    router.HandleFunc("/health", service.healthHandler).Methods("GET")
    router.HandleFunc("/reason", service.reasonHandler).Methods("GET")

    port := os.Getenv("PORT")
    if port == "" {
        port = "80"
    }

    service.logger.Printf("Axon service starting on port %s", port)
    log.Fatal(http.ListenAndServe(":"+port, router))
}

func (s *AxonService) loadSecrets() error {
    secretID := os.Getenv("AXON_SECRET_ARN")

    input := &secretsmanager.GetSecretValueInput{
        SecretId: aws.String(secretID),
    }

    result, err := s.secrets.GetSecretValue(input)
    if err != nil {
        return err
    }

    // Parse and validate secrets
    var secrets map[string]string
    if err := json.Unmarshal([]byte(*result.SecretString), &secrets); err != nil {
        return err
    }

    s.logger.Printf("Successfully loaded secrets for Axon service")
    return nil
}

func (s *AxonService) correlationMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        correlationID := r.Header.Get("X-Correlation-ID")
        if correlationID == "" {
            correlationID = generateCorrelationID()
        }

        // Add to context and response headers
        ctx := context.WithValue(r.Context(), "correlationID", correlationID)
        w.Header().Set("X-Correlation-ID", correlationID)

        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func (s *AxonService) loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()

        correlationID := r.Context().Value("correlationID").(string)

        s.logger.Printf("REQUEST [%s] %s %s", correlationID, r.Method, r.URL.Path)

        next.ServeHTTP(w, r)

        duration := time.Since(start)
        s.logger.Printf("RESPONSE [%s] %s %s - %v", correlationID, r.Method, r.URL.Path, duration)
    })
}

func (s *AxonService) healthHandler(w http.ResponseWriter, r *http.Request) {
    correlationID := r.Context().Value("correlationID").(string)

    response := HealthResponse{
        Status:    "healthy",
        Service:   "axon",
        Timestamp: time.Now(),
    }

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(response)

    s.logger.Printf("HEALTH [%s] Service is healthy", correlationID)
}

func (s *AxonService) reasonHandler(w http.ResponseWriter, r *http.Request) {
    correlationID := r.Context().Value("correlationID").(string)

    response := ReasonResponse{
        Message:   "Axon heartbeat OK",
        Service:   "axon",
        Timestamp: time.Now(),
    }

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(response)

    s.logger.Printf("REASON [%s] Reasoning completed successfully", correlationID)
}

func generateCorrelationID() string {
    return fmt.Sprintf("%d", time.Now().UnixNano())
}
```

**File: services/axon/Dockerfile**

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates
WORKDIR /root/

# Copy the binary
COPY --from=builder /app/main .

# Create non-root user
RUN adduser -D -s /bin/sh appuser
USER appuser

EXPOSE 80

CMD ["./main"]
```

**File: services/axon/go.mod**

```go
module axon-service

go 1.21

require (
    github.com/aws/aws-sdk-go v1.44.122
    github.com/gorilla/mux v1.8.0
)
```

**Test Step 2.1:**

```bash
cd services/axon

# Build locally
go mod tidy
go build -o axon .

# Test health endpoint
./axon &
curl http://localhost:80/health
curl http://localhost:80/reason

# Build Docker image
docker build -t axon-test .
docker run -p 8080:80 axon-test
curl http://localhost:8080/health
```

### Step 2.2: Orbit Service Development (2-3 hours)

Create the Orbit dispatcher service with governance integration.

**File: services/orbit/main.go**

```go
package main

import (
    "bytes"
    "context"
    "crypto/sha256"
    "encoding/hex"
    "encoding/json"
    "fmt"
    "io"
    "log"
    "net/http"
    "os"
    "time"

    "github.com/aws/aws-sdk-go/aws"
    "github.com/aws/aws-sdk-go/aws/session"
    "github.com/aws/aws-sdk-go/service/lambda"
    "github.com/gorilla/mux"
)

type OrbitService struct {
    lambdaClient *lambda.Lambda
    httpClient   *http.Client
    logger       *log.Logger
}

type GovernanceRequest struct {
    Service string `json:"service"`
    Intent  string `json:"intent"`
}

type GovernanceResponse struct {
    Allowed bool   `json:"allowed"`
    Reason  string `json:"reason,omitempty"`
}

type DispatchResponse struct {
    Status     string    `json:"status"`
    Message    string    `json:"message"`
    Timestamp  time.Time `json:"timestamp"`
}

func main() {
    // Initialize AWS session
    sess, err := session.NewSession(&aws.Config{
        Region: aws.String(os.Getenv("AWS_REGION")),
    })
    if err != nil {
        log.Fatalf("Failed to create AWS session: %v", err)
    }

    service := &OrbitService{
        lambdaClient: lambda.New(sess),
        httpClient: &http.Client{
            Timeout: 30 * time.Second,
        },
        logger: log.New(os.Stdout, "[ORBIT] ", log.LstdFlags),
    }

    router := mux.NewRouter()

    // Add middleware
    router.Use(service.correlationMiddleware)
    router.Use(service.loggingMiddleware)

    // Routes
    router.HandleFunc("/health", service.healthHandler).Methods("GET")
    router.HandleFunc("/dispatch", service.dispatchHandler).Methods("POST")

    port := os.Getenv("PORT")
    if port == "" {
        port = "80"
    }

    service.logger.Printf("Orbit service starting on port %s", port)
    log.Fatal(http.ListenAndServe(":"+port, router))
}

func (s *OrbitService) correlationMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        correlationID := r.Header.Get("X-Correlation-ID")
        if correlationID == "" {
            correlationID = generateCorrelationID()
        }

        ctx := context.WithValue(r.Context(), "correlationID", correlationID)
        w.Header().Set("X-Correlation-ID", correlationID)

        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func (s *OrbitService) loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        correlationID := r.Context().Value("correlationID").(string)

        s.logger.Printf("REQUEST [%s] %s %s", correlationID, r.Method, r.URL.Path)

        next.ServeHTTP(w, r)

        duration := time.Since(start)
        s.logger.Printf("RESPONSE [%s] %s %s - %v", correlationID, r.Method, r.URL.Path, duration)
    })
}

func (s *OrbitService) healthHandler(w http.ResponseWriter, r *http.Request) {
    correlationID := r.Context().Value("correlationID").(string)

    response := map[string]interface{}{
        "status":    "healthy",
        "service":   "orbit",
        "timestamp": time.Now(),
    }

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(response)

    s.logger.Printf("HEALTH [%s] Service is healthy", correlationID)
}

func (s *OrbitService) dispatchHandler(w http.ResponseWriter, r *http.Request) {
    correlationID := r.Context().Value("correlationID").(string)

    // Step 1: Check governance
    governanceReq := GovernanceRequest{
        Service: "orbit",
        Intent:  "call_reasoning",
    }

    allowed, reason, err := s.checkGovernance(governanceReq, correlationID)
    if err != nil {
        s.logger.Printf("GOVERNANCE_ERROR [%s] %v", correlationID, err)
        http.Error(w, "Governance check failed", http.StatusInternalServerError)
        return
    }

    if !allowed {
        s.logger.Printf("GOVERNANCE_DENIED [%s] %s", correlationID, reason)
        response := map[string]interface{}{
            "status":    "denied",
            "reason":    reason,
            "timestamp": time.Now(),
        }
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusForbidden)
        json.NewEncoder(w).Encode(response)
        return
    }

    // Step 2: Call Axon service
    axonResponse, err := s.callAxon(correlationID)
    if err != nil {
        s.logger.Printf("AXON_ERROR [%s] %v", correlationID, err)
        http.Error(w, "Failed to call Axon", http.StatusInternalServerError)
        return
    }

    // Step 3: Return successful response
    response := DispatchResponse{
        Status:    "success",
        Message:   axonResponse,
        Timestamp: time.Now(),
    }

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    json.NewEncoder(w).Encode(response)

    s.logger.Printf("DISPATCH_SUCCESS [%s] Request completed", correlationID)
}

func (s *OrbitService) checkGovernance(req GovernanceRequest, correlationID string) (bool, string, error) {
    payload, err := json.Marshal(req)
    if err != nil {
        return false, "", err
    }

    input := &lambda.InvokeInput{
        FunctionName: aws.String(os.Getenv("GOVERNANCE_FUNCTION_NAME")),
        Payload:      payload,
    }

    result, err := s.lambdaClient.Invoke(input)
    if err != nil {
        return false, "", err
    }

    var response GovernanceResponse
    if err := json.Unmarshal(result.Payload, &response); err != nil {
        return false, "", err
    }

    return response.Allowed, response.Reason, nil
}

func (s *OrbitService) callAxon(correlationID string) (string, error) {
    axonURL := os.Getenv("AXON_SERVICE_URL")
    if axonURL == "" {
        axonURL = "http://axon/reason"
    }

    req, err := http.NewRequest("GET", axonURL, nil)
    if err != nil {
        return "", err
    }

    // Add correlation ID and SigV4 signing (simplified for now)
    req.Header.Set("X-Correlation-ID", correlationID)

    resp, err := s.httpClient.Do(req)
    if err != nil {
        return "", err
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        return "", fmt.Errorf("Axon returned status %d", resp.StatusCode)
    }

    body, err := io.ReadAll(resp.Body)
    if err != nil {
        return "", err
    }

    var axonResp map[string]interface{}
    if err := json.Unmarshal(body, &axonResp); err != nil {
        return "", err
    }

    if message, ok := axonResp["message"].(string); ok {
        return message, nil
    }

    return "Axon response received", nil
}

func generateCorrelationID() string {
    hash := sha256.Sum256([]byte(fmt.Sprintf("%d", time.Now().UnixNano())))
    return hex.EncodeToString(hash[:])[:16]
}
```

**File: services/orbit/Dockerfile**

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates
WORKDIR /root/

# Copy the binary
COPY --from=builder /app/main .

# Create non-root user
RUN adduser -D -s /bin/sh appuser
USER appuser

EXPOSE 80

CMD ["./main"]
```

**Test Step 2.2:**

```bash
cd services/orbit

# Build locally
go mod tidy
go build -o orbit .

# Test health endpoint
./orbit &
curl http://localhost:80/health

# Build Docker image
docker build -t orbit-test .
```

### Step 2.3: ECS Task Definitions (1-2 hours)

**File: infra/modules/ecs/task-definitions/axon.json**

```json
{
  "family": "${PROJECT_NAME}-axon",
  "taskRoleArn": "${AXON_ROLE_ARN}",
  "executionRoleArn": "${ECS_EXECUTION_ROLE_ARN}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "axon",
      "image": "${AXON_ECR_REPO}:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "AWS_REGION",
          "value": "${AWS_REGION}"
        },
        {
          "name": "AXON_SECRET_ARN",
          "value": "${AXON_SECRET_ARN}"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "${AXON_SECRET_ARN}:database_url"
        },
        {
          "name": "API_KEY",
          "valueFrom": "${AXON_SECRET_ARN}:api_key"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/${PROJECT_NAME}-axon",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:80/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

**File: infra/modules/ecs/task-definitions/orbit.json**

```json
{
  "family": "${PROJECT_NAME}-orbit",
  "taskRoleArn": "${ORBIT_ROLE_ARN}",
  "executionRoleArn": "${ECS_EXECUTION_ROLE_ARN}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "orbit",
      "image": "${ORBIT_ECR_REPO}:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "AWS_REGION",
          "value": "${AWS_REGION}"
        },
        {
          "name": "ORBIT_SECRET_ARN",
          "value": "${ORBIT_SECRET_ARN}"
        },
        {
          "name": "GOVERNANCE_FUNCTION_NAME",
          "value": "${GOVERNANCE_FUNCTION_NAME}"
        },
        {
          "name": "AXON_SERVICE_URL",
          "value": "http://axon.${NAMESPACE}/reason"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "${ORBIT_SECRET_ARN}:database_url"
        },
        {
          "name": "API_KEY",
          "valueFrom": "${ORBIT_SECRET_ARN}:api_key"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/${PROJECT_NAME}-orbit",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:80/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

**File: infra/modules/ecs/services.tf**

```hcl
resource "aws_ecs_service" "axon" {
  name            = "${var.project_name}-axon"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.axon.arn
  desired_count   = 2

  network_configuration {
    security_groups  = [aws_security_group.axon.id]
    subnets          = aws_subnet.axon_runtime[*].id
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.axon.arn
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.axon.arn
    container_name   = "axon"
    container_port   = 80
  }

  deployment_controller {
    type = "ECS"
  }

  tags = {
    Name = "${var.project_name}-axon-service"
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_execution
  ]
}

resource "aws_ecs_service" "orbit" {
  name            = "${var.project_name}-orbit"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.orbit.arn
  desired_count   = 2

  network_configuration {
    security_groups  = [aws_security_group.orbit.id]
    subnets          = aws_subnet.private[*].id
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.orbit.arn
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.orbit.arn
    container_name   = "orbit"
    container_port   = 80
  }

  deployment_controller {
    type = "ECS"
  }

  tags = {
    Name = "${var.project_name}-orbit-service"
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_execution
  ]
}
```

**Test Step 2.3:**

```bash
cd infra
terraform plan -target=module.ecs
terraform apply -target=module.ecs

# Check services are running
aws ecs describe-services --cluster $CLUSTER_NAME --services ${PROJECT_NAME}-axon ${PROJECT_NAME}-orbit

# Check task definitions
aws ecs describe-task-definition --task-definition ${PROJECT_NAME}-axon
```

### Step 2.4: Unit Tests (1 hour)

**File: services/axon/tests/unit/health_test.go**

```go
package tests

import (
    "net/http"
    "net/http/httptest"
    "testing"
    "time"

    "axon-service/handlers"
)

func TestHealthHandler(t *testing.T) {
    req, err := http.NewRequest("GET", "/health", nil)
    if err != nil {
        t.Fatal(err)
    }

    rr := httptest.NewRecorder()
    handler := http.HandlerFunc(handlers.HealthHandler)

    handler.ServeHTTP(rr, req)

    if status := rr.Code; status != http.StatusOK {
        t.Errorf("Health handler returned wrong status code: got %v want %v", status, http.StatusOK)
    }

    expected := `{"status":"healthy","service":"axon"}`
    if rr.Body.String() != expected {
        t.Errorf("Health handler returned unexpected body: got %v want %v", rr.Body.String(), expected)
    }
}

func TestHealthHandlerCorrelationID(t *testing.T) {
    req, err := http.NewRequest("GET", "/health", nil)
    if err != nil {
        t.Fatal(err)
    }

    correlationID := "test-correlation-id"
    req.Header.Set("X-Correlation-ID", correlationID)

    rr := httptest.NewRecorder()
    handler := http.HandlerFunc(handlers.HealthHandler)

    handler.ServeHTTP(rr, req)

    if correlationIDHeader := rr.Header().Get("X-Correlation-ID"); correlationIDHeader != correlationID {
        t.Errorf("Correlation ID not propagated: got %v want %v", correlationIDHeader, correlationID)
    }
}
```

**Test Step 2.4:**

```bash
cd services/axon
go test ./tests/unit/ -v

cd ../orbit
go test ./tests/unit/ -v
```

### Step 2.5: Integration Tests (1 hour)

**File: services/orbit/tests/integration/dispatch_test.go**

```go
package integration

import (
    "bytes"
    "net/http"
    "net/http/httptest"
    "testing"
    "time"

    "orbit-service/handlers"
)

func TestDispatchWithGovernance(t *testing.T) {
    // Mock governance response (always allow for testing)
    governanceServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        w.Write([]byte(`{"allowed": true}`))
    }))
    defer governanceServer.Close()

    // Mock Axon service
    axonServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        w.Write([]byte(`{"message": "Axon heartbeat OK"}`))
    }))
    defer axonServer.Close()

    // Create request to Orbit dispatch endpoint
    req, err := http.NewRequest("POST", "/dispatch", bytes.NewBuffer([]byte{}))
    if err != nil {
        t.Fatal(err)
    }

    rr := httptest.NewRecorder()
    handler := http.HandlerFunc(handlers.DispatchHandler)

    // Set environment variables for test
    t.Setenv("GOVERNANCE_FUNCTION_URL", governanceServer.URL)
    t.Setenv("AXON_SERVICE_URL", axonServer.URL)

    handler.ServeHTTP(rr, req)

    if status := rr.Code; status != http.StatusOK {
        t.Errorf("Dispatch handler returned wrong status code: got %v want %v", status, http.StatusOK)
    }
}

func TestDispatchGovernanceDenied(t *testing.T) {
    // Mock governance response (deny)
    governanceServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        w.Write([]byte(`{"allowed": false, "reason": "Policy violation"}`))
    }))
    defer governanceServer.Close()

    req, err := http.NewRequest("POST", "/dispatch", bytes.NewBuffer([]byte{}))
    if err != nil {
        t.Fatal(err)
    }

    rr := httptest.NewRecorder()
    handler := http.HandlerFunc(handlers.DispatchHandler)

    t.Setenv("GOVERNANCE_FUNCTION_URL", governanceServer.URL)

    handler.ServeHTTP(rr, req)

    if status := rr.Code; status != http.StatusForbidden {
        t.Errorf("Dispatch handler should return 403 when governance denies: got %v want %v", status, http.StatusForbidden)
    }
}
```

**Test Step 2.5:**

```bash
cd services/orbit
go test ./tests/integration/ -v

# Test with mocks
go test ./tests/integration/ -tags=integration
```

## Acceptance Criteria

- [ ] Axon service responds to `/health` with healthy status
- [ ] Axon service responds to `/reason` with heartbeat message
- [ ] Orbit service responds to `/health` with healthy status
- [ ] Orbit service calls governance before dispatching
- [ ] Governance denial blocks Axon calls
- [ ] Correlation IDs propagated across services
- [ ] Structured JSON logs generated
- [ ] Docker images build successfully (< 50MB)
- [ ] Unit tests pass (>80% coverage)
- [ ] Integration tests pass
- [ ] Services deploy to ECS successfully
- [ ] Health checks pass in ECS

## Rollback Procedure

If microservices deployment fails:

```bash
# Stop ECS services
aws ecs update-service --cluster $CLUSTER_NAME --service ${PROJECT_NAME}-axon --desired-count 0
aws ecs update-service --cluster $CLUSTER_NAME --service ${PROJECT_NAME}-orbit --desired-count 0

# Delete task definitions
aws ecs deregister-task-definition --task-definition ${PROJECT_NAME}-axon
aws ecs deregister-task-definition --task-definition ${PROJECT_NAME}-orbit

# Revert to previous images if needed
```

## Testing Script

Create `tasks/test-task-2.sh`:

```bash
#!/bin/bash
set -e

echo "Testing Task 2: Microservices Development"

# Test Axon service locally
cd services/axon
docker build -t axon-test .
docker run -d --name axon-test -p 8080:80 axon-test
sleep 5

# Test health endpoint
HEALTH_STATUS=$(curl -s http://localhost:8080/health | jq -r .status)
if [ "$HEALTH_STATUS" != "healthy" ]; then
    echo "❌ Axon health check failed"
    docker logs axon-test
    docker stop axon-test
    docker rm axon-test
    exit 1
fi
echo "✅ Axon health check passed"

# Test reason endpoint
REASON_MSG=$(curl -s http://localhost:8080/reason | jq -r .message)
if [ "$REASON_MSG" != "Axon heartbeat OK" ]; then
    echo "❌ Axon reason endpoint failed"
    exit 1
fi
echo "✅ Axon reason endpoint passed"

docker stop axon-test
docker rm axon-test

# Test Orbit service locally
cd ../orbit
docker build -t orbit-test .

# For Orbit, we need mocks for governance and axon
# This would require more complex setup for full integration testing

# Run unit tests
cd ../axon
go test ./tests/unit/ -v
cd ../orbit
go test ./tests/unit/ -v

# Test ECS deployment
CLUSTER_NAME="${PROJECT_NAME}-cluster"
AXON_SERVICE=$(aws ecs describe-services --cluster $CLUSTER_NAME --services ${PROJECT_NAME}-axon --query 'services[0].runningCount')
ORBIT_SERVICE=$(aws ecs describe-services --cluster $CLUSTER_NAME --services ${PROJECT_NAME}-orbit --query 'services[0].runningCount')

if [ "$AXON_SERVICE" -lt 2 ]; then
    echo "❌ Axon service not running properly"
    exit 1
fi

if [ "$ORBIT_SERVICE" -lt 2 ]; then
    echo "❌ Orbit service not running properly"
    exit 1
fi
echo "✅ Services deployed to ECS"

echo ""
echo "🎉 Task 2 Microservices Development: PASSED"
```
