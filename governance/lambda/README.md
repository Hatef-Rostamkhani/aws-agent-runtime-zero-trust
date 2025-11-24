# Governance Lambda Function

This Lambda function implements the governance layer for the AWS Agent Runtime Zero Trust architecture. It enforces the "Think → Govern → Act" pattern by evaluating policies before allowing Orbit to call Axon.

## Overview

The governance Lambda function:
- Evaluates access requests based on stored policies in DynamoDB
- Supports time-based restrictions
- Supports rate limiting (simplified implementation)
- Supports custom condition evaluation
- Returns structured JSON responses with correlation IDs
- Logs all decisions for audit purposes

## Architecture

- **Runtime**: Python 3.9
- **Handler**: `handler.lambda_handler`
- **Dependencies**: boto3, botocore
- **Storage**: DynamoDB table for policies
- **Logging**: CloudWatch Logs with structured JSON

## Request Format

```json
{
  "service": "orbit",
  "intent": "call_reasoning",
  "context": {
    "user_type": "active"
  }
}
```

## Response Format

**Allowed:**
```json
{
  "service": "orbit",
  "intent": "call_reasoning",
  "allowed": true,
  "reason": "Request authorized",
  "timestamp": 1234567890.123,
  "correlation_id": "abc-123"
}
```

**Denied:**
```json
{
  "service": "orbit",
  "intent": "call_reasoning",
  "allowed": false,
  "reason": "Policy is disabled",
  "timestamp": 1234567890.123,
  "correlation_id": "abc-123"
}
```

## Environment Variables

- `POLICY_TABLE_NAME`: Name of the DynamoDB table containing policies (required)

## Policy Evaluation Flow

1. Retrieve policy from DynamoDB using composite key (service, intent)
2. Check if policy exists
3. Check if policy is enabled
4. Evaluate time restrictions (if configured)
5. Check rate limits (if configured)
6. Evaluate custom conditions (if any)
7. Return (allowed: bool, reason: str)

## Local Development

### Prerequisites
- Python 3.9+
- AWS credentials configured
- DynamoDB table created

### Setup

```bash
cd governance/lambda
pip install -r requirements.txt
```

### Testing

```bash
# Run unit tests
python -m pytest tests/unit/ -v

# Run with coverage
python -m pytest tests/unit/ --cov=handler --cov-report=html
```

### Local Testing

```python
from handler import lambda_handler

event = {
    'service': 'orbit',
    'intent': 'call_reasoning'
}

result = lambda_handler(event, None)
print(result)
```

## Deployment

The Lambda function is deployed via Terraform in `governance/terraform/`. The deployment package includes:
- `handler.py`
- `policies.py`
- Dependencies from `requirements.txt`

## Monitoring

- CloudWatch Logs: `/aws/lambda/{project_name}-governance`
- CloudWatch Metrics: Errors, Duration, Invocations
- CloudWatch Alarms: Error rate, Duration threshold

## Security

- IAM role with minimal permissions (DynamoDB read, CloudWatch logs, VPC networking)
- VPC configuration for network isolation
- Encryption at rest for DynamoDB
- Correlation ID propagation for request tracing

