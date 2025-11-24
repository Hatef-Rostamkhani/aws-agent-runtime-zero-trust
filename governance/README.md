# Governance Layer

The governance layer implements the "Think → Govern → Act" pattern for the AWS Agent Runtime Zero Trust architecture. It acts as a pre-call authorization layer that evaluates policies before allowing Orbit to communicate with Axon.

## Overview

The governance layer consists of:
- **Lambda Function**: Policy evaluation engine
- **DynamoDB Table**: Policy storage
- **Terraform Infrastructure**: IAM roles, VPC configuration, CloudWatch
- **Policy Management**: Default policies and loading scripts

## Architecture

```
Orbit Service → Governance Lambda → DynamoDB (Policies)
                    ↓
              (allowed/denied)
                    ↓
              Axon Service (if allowed)
```

## Components

### Lambda Function
- Evaluates access requests
- Supports time restrictions, rate limits, and custom conditions
- Returns structured JSON responses
- Logs all decisions

### DynamoDB Table
- Stores governance policies
- Composite key: (service, intent)
- PAY_PER_REQUEST billing mode
- Point-in-time recovery enabled

### Policies
- JSON-based policy definitions
- Schema validation
- Default policies for common scenarios
- Scripts for loading policies

## Quick Start

### Deploy Infrastructure

```bash
cd governance/terraform
terraform init
terraform plan
terraform apply
```

### Load Default Policies

Policies are automatically loaded via Terraform. To manually load:

```bash
export POLICY_TABLE_NAME=agent-runtime-governance-policies
python scripts/load-policies.py
```

### Test Governance

```bash
aws lambda invoke \
  --function-name agent-runtime-governance \
  --payload '{"service": "orbit", "intent": "call_reasoning"}' \
  output.json

cat output.json
```

## Policy Structure

Policies define access control rules:

```json
{
  "service": "orbit",
  "intent": "call_reasoning",
  "enabled": true,
  "description": "Allow Orbit to call Axon reasoning service",
  "time_restrictions": {
    "allowed_hours": [0, 1, 2, ..., 23]
  },
  "rate_limits": {
    "requests_per_minute": 100,
    "requests_per_hour": 1000
  },
  "conditions": []
}
```

See [policies/README.md](./policies/README.md) for detailed policy documentation.

## Default Policies

1. **orbit:call_reasoning** - Allows Orbit to call Axon (100/min, 1000/hour)
2. **orbit:call_metrics** - Allows Orbit to retrieve metrics (60/min, 500/hour)
3. **admin:manage_policies** - Allows admin policy management (10/min, 100/hour)

## Integration

The governance Lambda is invoked by the Orbit service via AWS SDK:

```go
governanceClient.CheckPermission(
    GovernanceRequest{
        Service: "orbit",
        Intent:  "call_reasoning",
    },
    correlationID,
)
```

## Monitoring

- **CloudWatch Logs**: `/aws/lambda/{project_name}-governance`
- **CloudWatch Metrics**: Errors, Duration, Invocations
- **CloudWatch Alarms**: Error rate, Duration threshold

## Security

- IAM role with minimal permissions
- VPC configuration for network isolation
- Encryption at rest for DynamoDB
- Correlation ID propagation
- Audit logging of all decisions

## Testing

### Unit Tests
```bash
cd governance/lambda
python -m pytest tests/unit/ -v
```

### Integration Tests
```bash
# Test with deployed Lambda
aws lambda invoke \
  --function-name agent-runtime-governance \
  --payload '{"service": "orbit", "intent": "call_reasoning"}' \
  output.json
```

## Directory Structure

```
governance/
├── lambda/              # Lambda function code
│   ├── handler.py       # Main Lambda handler
│   ├── policies.py      # Policy utilities
│   ├── requirements.txt # Python dependencies
│   └── tests/          # Unit tests
├── terraform/           # Infrastructure as Code
│   ├── lambda.tf       # Lambda function
│   ├── dynamodb.tf     # DynamoDB table
│   ├── iam.tf          # IAM roles and policies
│   └── cloudwatch.tf   # Logging and alarms
├── policies/           # Policy definitions
│   ├── default.json    # Default policies
│   └── schema.json     # Policy schema
└── scripts/            # Utility scripts
    └── load-policies.py # Policy loading script
```

## Documentation

- [Lambda Function README](./lambda/README.md)
- [Policies README](./policies/README.md)

## Troubleshooting

### Lambda Function Not Found
- Check Terraform deployment completed successfully
- Verify function name matches: `{project_name}-governance`

### Policies Not Found
- Verify DynamoDB table exists
- Check policies loaded via Terraform or script
- Verify table name matches `POLICY_TABLE_NAME` environment variable

### Access Denied
- Check IAM permissions for Lambda role
- Verify Orbit task role has Lambda invoke permission
- Check policy exists and is enabled

## Future Enhancements

- Rate limiting with Redis/DynamoDB counters
- Policy versioning
- Policy audit trail
- Advanced condition evaluation
- Policy management API

