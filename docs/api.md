# API Documentation

## Overview

The AWS Agent Runtime exposes REST APIs for health monitoring, reasoning execution, and request dispatching with governance.

## Base URL
```
https://<alb-dns>/
```

## Authentication

All API requests require AWS SigV4 signing. Requests without proper signatures will be rejected with 401 Unauthorized.

### SigV4 Signing Example
```bash
# Using AWS CLI for testing
aws lambda invoke --function-name test-signer output.json --payload '{"message": "test"}'
```

## Endpoints

### GET /health

Health check endpoint for load balancer monitoring.

**Response:**
```json
{
  "status": "healthy",
  "service": "orbit",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0"
}
```

**Status Codes:**
- `200 OK`: Service is healthy
- `503 Service Unavailable`: Service is unhealthy

### POST /dispatch

Main endpoint for dispatching requests to the Axon reasoning service with governance checks.

**Request:**
```json
{
  "intent": "call_reasoning",
  "context": {
    "user_id": "user123",
    "request_id": "req456"
  }
}
```

**Response (Success):**
```json
{
  "status": "success",
  "message": "Axon heartbeat OK",
  "correlation_id": "abc123-def456",
  "timestamp": "2024-01-15T10:30:00Z",
  "governance": {
    "allowed": true,
    "reason": "Request authorized",
    "decision_time_ms": 45
  }
}
```

**Response (Governance Denied):**
```json
{
  "status": "denied",
  "reason": "Rate limit exceeded",
  "correlation_id": "abc123-def456",
  "timestamp": "2024-01-15T10:30:00Z",
  "governance": {
    "allowed": false,
    "reason": "Rate limit exceeded",
    "decision_time_ms": 23
  }
}
```

**Status Codes:**
- `200 OK`: Request processed successfully
- `403 Forbidden`: Governance denied the request
- `500 Internal Server Error`: Server error
- `503 Service Unavailable`: Service temporarily unavailable

### GET /metrics

Prometheus-compatible metrics endpoint (if enabled).

**Response:**
```
# HELP orbit_requests_total Total number of requests
# TYPE orbit_requests_total counter
orbit_requests_total{method="POST",endpoint="/dispatch",status="200"} 12543

# HELP orbit_governance_decisions_total Governance decisions made
# TYPE orbit_governance_decisions_total counter
orbit_governance_decisions_total{decision="allowed"} 12456
orbit_governance_decisions_total{decision="denied"} 87
```

## Request/Response Headers

### Request Headers
- `X-Correlation-ID`: Unique request identifier (auto-generated if not provided)
- `Authorization`: AWS SigV4 signature
- `X-Amz-Date`: Request timestamp
- `Content-Type`: `application/json`

### Response Headers
- `X-Correlation-ID`: Echoed correlation ID
- `Content-Type`: `application/json`
- `X-Request-ID`: Internal request identifier

## Error Handling

### Error Response Format
```json
{
  "error": "Error message",
  "correlation_id": "abc123-def456",
  "timestamp": "2024-01-15T10:30:00Z",
  "details": {
    "field": "intent",
    "issue": "required field missing"
  }
}
```

### Common Errors
- `INVALID_SIGNATURE`: SigV4 signature verification failed
- `MISSING_AUTHORIZATION`: Authorization header missing
- `GOVERNANCE_DENIED`: Request blocked by governance policy
- `SERVICE_UNAVAILABLE`: Backend service temporarily unavailable
- `RATE_LIMIT_EXCEEDED`: Too many requests

## Rate Limiting

- **Global Rate Limit**: 1000 requests per minute
- **Per IP**: 100 requests per minute
- **Governance Calls**: 100 requests per minute

Rate limit headers are included in responses:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 987
X-RateLimit-Reset: 1642156800
```

## Monitoring and Observability

### Metrics
- Request count, latency, error rates
- Governance decision counts
- Service health status

### Logs
All requests are logged with correlation IDs for tracing:
```
2024-01-15T10:30:00Z [INFO] REQUEST [abc123-def456] POST /dispatch 200 45ms
2024-01-15T10:30:00Z [INFO] GOVERNANCE [abc123-def456] allowed: Request authorized
2024-01-15T10:30:00Z [INFO] AXON_CALL [abc123-def456] success: Axon heartbeat OK
```

### Tracing
Distributed tracing with AWS X-Ray (when enabled):
- Request flow: ALB → Orbit → Governance → Axon
- Service dependencies and latency
- Error propagation

## SDK Examples

### Python Client
```python
import boto3
import requests
from botocore.awsrequest import AWSRequest
from botocore.auth import SigV4Auth

class AgentRuntimeClient:
    def __init__(self, endpoint_url: str, region: str = 'us-east-1'):
        self.endpoint_url = endpoint_url
        self.region = region
        self.session = boto3.Session()

    def _sign_request(self, method: str, url: str, body: str = None) -> dict:
        """Sign request with SigV4"""
        request = AWSRequest(
            method=method,
            url=url,
            data=body
        )

        SigV4Auth(self.session.get_credentials(), 'execute-api', self.region).add_auth(request)

        return {
            'Authorization': request.headers['Authorization'],
            'X-Amz-Date': request.headers['X-Amz-Date']
        }

    def dispatch(self, intent: str = 'call_reasoning', context: dict = None) -> dict:
        """Dispatch a request"""
        url = f"{self.endpoint_url}/dispatch"
        payload = {
            'intent': intent,
            'context': context or {}
        }

        headers = self._sign_request('POST', url, json.dumps(payload))
        headers['Content-Type'] = 'application/json'

        response = requests.post(url, json=payload, headers=headers)
        return response.json()

    def health_check(self) -> dict:
        """Check service health"""
        url = f"{self.endpoint_url}/health"
        headers = self._sign_request('GET', url)

        response = requests.get(url, headers=headers)
        return response.json()

# Usage
client = AgentRuntimeClient('https://your-alb-dns')
result = client.dispatch('call_reasoning', {'user_id': 'user123'})
print(result)
```

### JavaScript/Node.js Client
```javascript
const AWS = require('aws-sdk');
const axios = require('axios');

class AgentRuntimeClient {
  constructor(endpointUrl, region = 'us-east-1') {
    this.endpointUrl = endpointUrl;
    this.region = region;
    this.credentials = new AWS.CredentialProviderChain();
  }

  async signRequest(method, url, body = null) {
    const request = {
      method: method,
      url: url,
      body: body,
      headers: {}
    };

    const signer = new AWS.Signers.V4(request, 'execute-api');
    signer.addAuthorization(this.credentials, new Date());

    return request.headers;
  }

  async dispatch(intent = 'call_reasoning', context = {}) {
    const url = `${this.endpointUrl}/dispatch`;
    const payload = { intent, context };

    const headers = await this.signRequest('POST', url, JSON.stringify(payload));
    headers['Content-Type'] = 'application/json';

    const response = await axios.post(url, payload, { headers });
    return response.data;
  }

  async healthCheck() {
    const url = `${this.endpointUrl}/health`;
    const headers = await this.signRequest('GET', url);

    const response = await axios.get(url, { headers });
    return response.data;
  }
}

// Usage
const client = new AgentRuntimeClient('https://your-alb-dns');
const result = await client.dispatch('call_reasoning', { userId: 'user123' });
console.log(result);
```

### Go Client
```go
package main

import (
    "bytes"
    "context"
    "crypto/tls"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "time"

    "github.com/aws/aws-sdk-go/aws"
    "github.com/aws/aws-sdk-go/aws/credentials"
    "github.com/aws/aws-sdk-go/aws/session"
    v4 "github.com/aws/aws-sdk-go/aws/signer/v4"
)

type AgentRuntimeClient struct {
    endpoint string
    signer   *v4.Signer
    client   *http.Client
}

type DispatchRequest struct {
    Intent  string                 `json:"intent"`
    Context map[string]interface{} `json:"context,omitempty"`
}

type DispatchResponse struct {
    Status       string    `json:"status"`
    Message      string    `json:"message,omitempty"`
    Reason       string    `json:"reason,omitempty"`
    CorrelationID string   `json:"correlation_id"`
    Timestamp    time.Time `json:"timestamp"`
}

func NewAgentRuntimeClient(endpoint string) *AgentRuntimeClient {
    sess := session.Must(session.NewSession())
    signer := v4.NewSigner(sess.Config.Credentials)

    return &AgentRuntimeClient{
        endpoint: endpoint,
        signer:   signer,
        client: &http.Client{
            Timeout: 30 * time.Second,
            Transport: &http.Transport{
                TLSClientConfig: &tls.Config{
                    InsecureSkipVerify: false,
                },
            },
        },
    }
}

func (c *AgentRuntimeClient) Dispatch(ctx context.Context, intent string, context map[string]interface{}) (*DispatchResponse, error) {
    url := c.endpoint + "/dispatch"

    reqData := DispatchRequest{
        Intent:  intent,
        Context: context,
    }

    jsonData, err := json.Marshal(reqData)
    if err != nil {
        return nil, fmt.Errorf("failed to marshal request: %w", err)
    }

    req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
    if err != nil {
        return nil, fmt.Errorf("failed to create request: %w", err)
    }

    req.Header.Set("Content-Type", "application/json")

    // Sign the request
    _, err = c.signer.Sign(req, bytes.NewReader(jsonData), "execute-api", "us-east-1", time.Now())
    if err != nil {
        return nil, fmt.Errorf("failed to sign request: %w", err)
    }

    resp, err := c.client.Do(req)
    if err != nil {
        return nil, fmt.Errorf("request failed: %w", err)
    }
    defer resp.Body.Close()

    body, err := io.ReadAll(resp.Body)
    if err != nil {
        return nil, fmt.Errorf("failed to read response: %w", err)
    }

    var response DispatchResponse
    if err := json.Unmarshal(body, &response); err != nil {
        return nil, fmt.Errorf("failed to unmarshal response: %w", err)
    }

    if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusForbidden {
        return &response, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
    }

    return &response, nil
}

func (c *AgentRuntimeClient) HealthCheck(ctx context.Context) (map[string]interface{}, error) {
    url := c.endpoint + "/health"

    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, fmt.Errorf("failed to create request: %w", err)
    }

    // Sign the request
    _, err = c.signer.Sign(req, nil, "execute-api", "us-east-1", time.Now())
    if err != nil {
        return nil, fmt.Errorf("failed to sign request: %w", err)
    }

    resp, err := c.client.Do(req)
    if err != nil {
        return nil, fmt.Errorf("request failed: %w", err)
    }
    defer resp.Body.Close()

    var result map[string]interface{}
    if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
        return nil, fmt.Errorf("failed to decode response: %w", err)
    }

    return result, nil
}

func main() {
    client := NewAgentRuntimeClient("https://your-alb-dns")

    // Health check
    health, err := client.HealthCheck(context.Background())
    if err != nil {
        fmt.Printf("Health check failed: %v\n", err)
        return
    }
    fmt.Printf("Health: %+v\n", health)

    // Dispatch request
    response, err := client.Dispatch(context.Background(), "call_reasoning", map[string]interface{}{
        "user_id": "user123",
    })
    if err != nil {
        fmt.Printf("Dispatch failed: %v\n", err)
        return
    }
    fmt.Printf("Response: %+v\n", response)
}
```

## Webhooks and Callbacks

### Governance Decision Webhooks (Future)

When governance decisions are made, webhooks can be configured to notify external systems:

```json
{
  "event": "governance_decision",
  "service": "orbit",
  "intent": "call_reasoning",
  "allowed": true,
  "reason": "Request authorized",
  "correlation_id": "abc123-def456",
  "timestamp": "2024-01-15T10:30:00Z",
  "context": {
    "user_id": "user123",
    "ip_address": "192.168.1.1"
  }
}
```

## Versioning

API versioning follows semantic versioning (MAJOR.MINOR.PATCH).

### Current Version: 1.0.0
- Initial release with core functionality
- Governance integration
- SigV4 authentication
- Structured logging

### Backward Compatibility
- All changes maintain backward compatibility within major versions
- Deprecation notices provided 3 months before removal
- New features are additive

## SLA and Support

### Service Level Agreement
- **Availability**: 99.9% uptime
- **Latency**: p95 < 500ms
- **Support**: 24/7 for critical issues

### Support Channels
- **Documentation**: This API documentation
- **Issues**: GitHub repository issues
- **Email**: api-support@barnabus.ai
- **Slack**: #api-support

## Changelog

### Version 1.0.0 (2024-01-15)
- Initial API release
- Health check endpoint
- Dispatch endpoint with governance
- SigV4 authentication
- Structured logging
