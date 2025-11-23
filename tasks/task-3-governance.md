# Task 3: Governance Layer

**Duration:** 4-6 hours
**Priority:** High
**Dependencies:** Task 1 (Infrastructure)

## Overview

Implement a lightweight governance Lambda function that enforces the "Think → Govern → Act" pattern. This function acts as a pre-call authorization layer for Orbit → Axon communication.

## Objectives

- [ ] Lambda function for governance decisions
- [ ] DynamoDB table for policy storage
- [ ] Policy evaluation engine
- [ ] RESTful API for governance checks
- [ ] Structured logging and metrics
- [ ] Unit and integration tests
- [ ] Infrastructure as Code (Terraform)

## Prerequisites

- [ ] Task 1 infrastructure deployed
- [ ] AWS CLI configured
- [ ] Node.js/Python runtime available
- [ ] Understanding of serverless architecture

## File Structure

```
governance/
├── lambda/
│   ├── handler.py (or index.js)
│   ├── policies.py
│   ├── requirements.txt (or package.json)
│   ├── tests/
│   │   ├── unit/
│   │   └── integration/
│   └── README.md
├── terraform/
│   ├── lambda.tf
│   ├── dynamodb.tf
│   ├── iam.tf
│   ├── cloudwatch.tf
│   ├── variables.tf
│   └── outputs.tf
├── policies/
│   ├── default.json
│   ├── schema.json
│   └── README.md
└── README.md
```

## Implementation Steps

### Step 3.1: Governance Lambda Function (2-3 hours)

Create the core governance logic in Python.

**File: governance/lambda/handler.py**

```python
import json
import logging
import os
import time
from decimal import Decimal
from typing import Dict, Any, Tuple

import boto3
from boto3.dynamodb.conditions import Key

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['POLICY_TABLE_NAME'])

class GovernanceService:
    def __init__(self):
        self.table = table

    def evaluate_request(self, service: str, intent: str, context: Dict[str, Any] = None) -> Tuple[bool, str]:
        """
        Evaluate governance request using stored policies.

        Args:
            service: The service making the request (e.g., 'orbit')
            intent: The intent of the request (e.g., 'call_reasoning')
            context: Additional context for policy evaluation

        Returns:
            Tuple of (allowed: bool, reason: str)
        """
        start_time = time.time()

        try:
            # Get policy for this service-intent combination
            policy = self._get_policy(service, intent)

            if not policy:
                logger.warning(f"No policy found for service={service}, intent={intent}")
                return False, f"No policy defined for {service}:{intent}"

            # Evaluate policy
            allowed, reason = self._evaluate_policy(policy, context or {})

            duration = time.time() - start_time
            logger.info(f"GOVERNANCE_EVALUATION service={service} intent={intent} allowed={allowed} duration={duration:.3f}s")

            return allowed, reason

        except Exception as e:
            logger.error(f"Governance evaluation failed: {str(e)}")
            return False, "Governance evaluation error"

    def _get_policy(self, service: str, intent: str) -> Dict[str, Any]:
        """Retrieve policy from DynamoDB."""
        try:
            response = self.table.get_item(
                Key={
                    'service': service,
                    'intent': intent
                }
            )

            if 'Item' in response:
                return response['Item']
            return None

        except Exception as e:
            logger.error(f"Failed to retrieve policy: {str(e)}")
            return None

    def _evaluate_policy(self, policy: Dict[str, Any], context: Dict[str, Any]) -> Tuple[bool, str]:
        """Evaluate policy against context."""

        # Check if policy is enabled
        if not policy.get('enabled', True):
            return False, "Policy is disabled"

        # Check time-based restrictions
        if not self._check_time_restrictions(policy):
            return False, "Request outside allowed time window"

        # Check rate limits (simplified)
        if not self._check_rate_limits(policy):
            return False, "Rate limit exceeded"

        # Check custom conditions
        conditions = policy.get('conditions', [])
        for condition in conditions:
            if not self._evaluate_condition(condition, context):
                return False, f"Condition not met: {condition.get('description', 'Unknown')}"

        return True, "Request authorized"

    def _check_time_restrictions(self, policy: Dict[str, Any]) -> bool:
        """Check if current time is within allowed window."""
        time_restrictions = policy.get('time_restrictions')
        if not time_restrictions:
            return True

        current_hour = time.gmtime().tm_hour

        allowed_hours = time_restrictions.get('allowed_hours', [])
        if allowed_hours and current_hour not in allowed_hours:
            return False

        return True

    def _check_rate_limits(self, policy: Dict[str, Any]) -> bool:
        """Check rate limits (simplified implementation)."""
        rate_limits = policy.get('rate_limits')
        if not rate_limits:
            return True

        # In a real implementation, this would check Redis or DynamoDB counters
        # For now, always allow
        return True

    def _evaluate_condition(self, condition: Dict[str, Any], context: Dict[str, Any]) -> bool:
        """Evaluate a single condition."""
        condition_type = condition.get('type')
        field = condition.get('field')
        operator = condition.get('operator')
        value = condition.get('value')

        if condition_type == 'context_check':
            actual_value = context.get(field)
            return self._compare_values(actual_value, operator, value)

        return True

    def _compare_values(self, actual: Any, operator: str, expected: Any) -> bool:
        """Compare values based on operator."""
        if operator == 'equals':
            return actual == expected
        elif operator == 'not_equals':
            return actual != expected
        elif operator == 'contains':
            return expected in actual if isinstance(actual, (str, list)) else False
        elif operator == 'greater_than':
            return actual > expected if isinstance(actual, (int, float)) else False
        elif operator == 'less_than':
            return actual < expected if isinstance(actual, (int, float)) else False

        return False

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for governance requests.
    """
    correlation_id = event.get('headers', {}).get('X-Correlation-ID', 'unknown')

    logger.info(f"GOVERNANCE_REQUEST [{correlation_id}] {json.dumps(event)}")

    try:
        # Parse request body
        if 'body' in event:
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        else:
            body = event

        service = body.get('service')
        intent = body.get('intent')
        request_context = body.get('context', {})

        if not service or not intent:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'X-Correlation-ID': correlation_id
                },
                'body': json.dumps({
                    'error': 'Missing required fields: service and intent',
                    'correlation_id': correlation_id
                })
            }

        # Evaluate governance request
        governance = GovernanceService()
        allowed, reason = governance.evaluate_request(service, intent, request_context)

        response_body = {
            'service': service,
            'intent': intent,
            'allowed': allowed,
            'reason': reason,
            'timestamp': time.time(),
            'correlation_id': correlation_id
        }

        status_code = 200 if allowed else 403

        logger.info(f"GOVERNANCE_RESPONSE [{correlation_id}] allowed={allowed} reason={reason}")

        return {
            'statusCode': status_code,
            'headers': {
                'Content-Type': 'application/json',
                'X-Correlation-ID': correlation_id
            },
            'body': json.dumps(response_body, default=str)
        }

    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error [{correlation_id}]: {str(e)}")
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'X-Correlation-ID': correlation_id
            },
            'body': json.dumps({
                'error': 'Invalid JSON in request body',
                'correlation_id': correlation_id
            })
        }

    except Exception as e:
        logger.error(f"Unexpected error [{correlation_id}]: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'X-Correlation-ID': correlation_id
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'correlation_id': correlation_id
            })
        }
```

**File: governance/lambda/policies.py**

```python
"""
Policy management utilities for governance service.
"""

import json
from typing import Dict, Any, List

class PolicyManager:
    @staticmethod
    def create_default_policies() -> List[Dict[str, Any]]:
        """Create default policies for the system."""
        return [
            {
                'service': 'orbit',
                'intent': 'call_reasoning',
                'enabled': True,
                'description': 'Allow Orbit to call Axon reasoning service',
                'time_restrictions': {
                    'allowed_hours': list(range(24))  # Allow all hours
                },
                'rate_limits': {
                    'requests_per_minute': 100,
                    'requests_per_hour': 1000
                },
                'conditions': [
                    {
                        'type': 'context_check',
                        'field': 'user_type',
                        'operator': 'not_equals',
                        'value': 'blocked',
                        'description': 'User must not be blocked'
                    }
                ]
            },
            {
                'service': 'orbit',
                'intent': 'call_metrics',
                'enabled': True,
                'description': 'Allow Orbit to retrieve metrics',
                'time_restrictions': {
                    'allowed_hours': list(range(24))
                },
                'rate_limits': {
                    'requests_per_minute': 60,
                    'requests_per_hour': 500
                },
                'conditions': []
            }
        ]

    @staticmethod
    def validate_policy(policy: Dict[str, Any]) -> Tuple[bool, str]:
        """Validate policy structure."""
        required_fields = ['service', 'intent', 'enabled']

        for field in required_fields:
            if field not in policy:
                return False, f"Missing required field: {field}"

        if not isinstance(policy['enabled'], bool):
            return False, "Field 'enabled' must be boolean"

        return True, "Policy is valid"

    @staticmethod
    def serialize_policy(policy: Dict[str, Any]) -> str:
        """Serialize policy for DynamoDB storage."""
        # Convert to DynamoDB format (handle Decimal types)
        def convert_to_dynamodb_format(obj):
            if isinstance(obj, dict):
                return {k: convert_to_dynamodb_format(v) for k, v in obj.items()}
            elif isinstance(obj, list):
                return [convert_to_dynamodb_format(item) for item in obj]
            elif isinstance(obj, (int, float)):
                return Decimal(str(obj))
            else:
                return obj

        return json.dumps(convert_to_dynamodb_format(policy), default=str)
```

**File: governance/lambda/requirements.txt**

```
boto3>=1.26.0
botocore>=1.29.0
```

**Test Step 3.1:**

```bash
cd governance/lambda

# Install dependencies
pip install -r requirements.txt

# Test locally
python -c "
from handler import lambda_handler
event = {'service': 'orbit', 'intent': 'call_reasoning'}
result = lambda_handler(event, None)
print('Result:', result)
"
```

### Step 3.2: Governance Infrastructure (1-2 hours)

**File: governance/terraform/dynamodb.tf**

```hcl
resource "aws_dynamodb_table" "policies" {
  name           = "${var.project_name}-governance-policies"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "service"
  range_key      = "intent"

  attribute {
    name = "service"
    type = "S"
  }

  attribute {
    name = "intent"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-governance-policies"
  }
}

# Default policies
resource "aws_dynamodb_table_item" "orbit_call_reasoning" {
  table_name = aws_dynamodb_table.policies.name
  hash_key   = aws_dynamodb_table.policies.hash_key
  range_key  = aws_dynamodb_table.policies.range_key

  item = jsonencode({
    service = "orbit"
    intent  = "call_reasoning"
    enabled = true
    description = "Allow Orbit to call Axon reasoning service"
    time_restrictions = {
      allowed_hours = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23]
    }
    rate_limits = {
      requests_per_minute = 100
      requests_per_hour = 1000
    }
    conditions = []
  })
}
```

**File: governance/terraform/lambda.tf**

```hcl
resource "aws_lambda_function" "governance" {
  function_name = "${var.project_name}-governance"
  runtime       = "python3.9"
  handler       = "handler.lambda_handler"
  timeout       = 30

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  role = aws_iam_role.governance_lambda.arn

  environment {
    variables = {
      POLICY_TABLE_NAME = aws_dynamodb_table.policies.name
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.governance_lambda.id]
  }

  tags = {
    Name = "${var.project_name}-governance"
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"
  source_dir  = "${path.module}/../lambda"
}

resource "aws_lambda_permission" "governance_invoke" {
  statement_id  = "AllowOrbitInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.governance.function_name
  principal     = "ecs-tasks.amazonaws.com"

  # Allow only from Orbit ECS service
  source_arn = var.orbit_task_role_arn
}
```

**File: governance/terraform/iam.tf**

```hcl
resource "aws_iam_role" "governance_lambda" {
  name = "${var.project_name}-governance-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-governance-lambda-role"
  }
}

resource "aws_iam_role_policy" "governance_lambda" {
  name = "${var.project_name}-governance-lambda-policy"
  role = aws_iam_role.governance_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.policies.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/${var.project_name}-governance:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_security_group" "governance_lambda" {
  name_prefix = "${var.project_name}-governance-lambda-"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-governance-lambda-sg"
  }
}
```

**Test Step 3.2:**

```bash
cd governance/terraform

# Initialize and plan
terraform init
terraform plan

# Apply infrastructure
terraform apply

# Test Lambda function
aws lambda invoke --function-name ${PROJECT_NAME}-governance \
  --payload '{"service": "orbit", "intent": "call_reasoning"}' \
  output.json

cat output.json
```

### Step 3.3: Policy Management (1 hour)

**File: governance/policies/default.json**

```json
[
  {
    "service": "orbit",
    "intent": "call_reasoning",
    "enabled": true,
    "description": "Allow Orbit to call Axon reasoning service",
    "time_restrictions": {
      "allowed_hours": [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23]
    },
    "rate_limits": {
      "requests_per_minute": 100,
      "requests_per_hour": 1000
    },
    "conditions": []
  },
  {
    "service": "orbit",
    "intent": "call_metrics",
    "enabled": true,
    "description": "Allow Orbit to retrieve metrics",
    "time_restrictions": {
      "allowed_hours": [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23]
    },
    "rate_limits": {
      "requests_per_minute": 60,
      "requests_per_hour": 500
    },
    "conditions": []
  },
  {
    "service": "admin",
    "intent": "manage_policies",
    "enabled": true,
    "description": "Allow admin to manage governance policies",
    "time_restrictions": null,
    "rate_limits": {
      "requests_per_minute": 10,
      "requests_per_hour": 100
    },
    "conditions": []
  }
]
```

**File: governance/policies/schema.json**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["service", "intent", "enabled"],
  "properties": {
    "service": {
      "type": "string",
      "description": "The service requesting access"
    },
    "intent": {
      "type": "string",
      "description": "The intent or action being requested"
    },
    "enabled": {
      "type": "boolean",
      "description": "Whether this policy is active"
    },
    "description": {
      "type": "string",
      "description": "Human-readable description of the policy"
    },
    "time_restrictions": {
      "type": ["object", "null"],
      "properties": {
        "allowed_hours": {
          "type": "array",
          "items": {
            "type": "integer",
            "minimum": 0,
            "maximum": 23
          }
        }
      }
    },
    "rate_limits": {
      "type": ["object", "null"],
      "properties": {
        "requests_per_minute": {
          "type": "integer",
          "minimum": 1
        },
        "requests_per_hour": {
          "type": "integer",
          "minimum": 1
        }
      }
    },
    "conditions": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["type", "field", "operator", "value"],
        "properties": {
          "type": {
            "type": "string",
            "enum": ["context_check"]
          },
          "field": {
            "type": "string"
          },
          "operator": {
            "type": "string",
            "enum": ["equals", "not_equals", "contains", "greater_than", "less_than"]
          },
          "value": {
            "type": ["string", "number", "boolean"]
          },
          "description": {
            "type": "string"
          }
        }
      }
    }
  }
}
```

**File: governance/scripts/load-policies.py**

```python
#!/usr/bin/env python3
"""
Script to load default policies into DynamoDB.
"""

import json
import boto3
import os
from decimal import Decimal

def load_policies(table_name: str, policies_file: str):
    """Load policies from JSON file into DynamoDB."""

    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)

    with open(policies_file, 'r') as f:
        policies = json.load(f)

    for policy in policies:
        # Convert numeric values to Decimal for DynamoDB
        def convert_numbers(obj):
            if isinstance(obj, dict):
                return {k: convert_numbers(v) for k, v in obj.items()}
            elif isinstance(obj, list):
                return [convert_numbers(item) for item in obj]
            elif isinstance(obj, (int, float)):
                return Decimal(str(obj))
            else:
                return obj

        policy_item = convert_numbers(policy)

        try:
            table.put_item(Item=policy_item)
            print(f"✓ Loaded policy: {policy['service']}:{policy['intent']}")
        except Exception as e:
            print(f"✗ Failed to load policy {policy['service']}:{policy['intent']}: {str(e)}")

if __name__ == "__main__":
    table_name = os.environ.get('POLICY_TABLE_NAME')
    policies_file = os.path.join(os.path.dirname(__file__), 'default.json')

    if not table_name:
        print("Error: POLICY_TABLE_NAME environment variable not set")
        exit(1)

    if not os.path.exists(policies_file):
        print(f"Error: Policies file not found: {policies_file}")
        exit(1)

    load_policies(table_name, policies_file)
    print("Policy loading completed")
```

**Test Step 3.3:**

```bash
# Load policies
cd governance
python scripts/load-policies.py

# Verify policies loaded
aws dynamodb scan --table-name ${PROJECT_NAME}-governance-policies
```

### Step 3.4: Unit Tests (1 hour)

**File: governance/lambda/tests/unit/test_handler.py**

```python
import json
import pytest
from unittest.mock import Mock, patch
from handler import GovernanceService, lambda_handler

class TestGovernanceService:
    def test_evaluate_request_allowed(self):
        """Test successful policy evaluation."""
        with patch('handler.table') as mock_table:
            mock_table.get_item.return_value = {
                'Item': {
                    'service': 'orbit',
                    'intent': 'call_reasoning',
                    'enabled': True
                }
            }

            service = GovernanceService()
            allowed, reason = service.evaluate_request('orbit', 'call_reasoning')

            assert allowed is True
            assert reason == "Request authorized"

    def test_evaluate_request_denied_no_policy(self):
        """Test denial when no policy exists."""
        with patch('handler.table') as mock_table:
            mock_table.get_item.return_value = {}

            service = GovernanceService()
            allowed, reason = service.evaluate_request('orbit', 'unknown_intent')

            assert allowed is False
            assert "No policy defined" in reason

    def test_evaluate_request_denied_disabled_policy(self):
        """Test denial when policy is disabled."""
        with patch('handler.table') as mock_table:
            mock_table.get_item.return_value = {
                'Item': {
                    'service': 'orbit',
                    'intent': 'call_reasoning',
                    'enabled': False
                }
            }

            service = GovernanceService()
            allowed, reason = service.evaluate_request('orbit', 'call_reasoning')

            assert allowed is False
            assert reason == "Policy is disabled"

class TestLambdaHandler:
    def test_lambda_handler_success(self):
        """Test successful lambda invocation."""
        event = {
            'service': 'orbit',
            'intent': 'call_reasoning'
        }

        with patch('handler.GovernanceService') as mock_service_class:
            mock_service = Mock()
            mock_service.evaluate_request.return_value = (True, "Request authorized")
            mock_service_class.return_value = mock_service

            response = lambda_handler(event, None)

            assert response['statusCode'] == 200
            body = json.loads(response['body'])
            assert body['allowed'] is True
            assert body['reason'] == "Request authorized"

    def test_lambda_handler_missing_fields(self):
        """Test lambda handler with missing required fields."""
        event = {
            'service': 'orbit'
            # missing intent
        }

        response = lambda_handler(event, None)

        assert response['statusCode'] == 400
        body = json.loads(response['body'])
        assert 'error' in body

    def test_lambda_handler_governance_denied(self):
        """Test lambda handler when governance denies request."""
        event = {
            'service': 'orbit',
            'intent': 'call_reasoning'
        }

        with patch('handler.GovernanceService') as mock_service_class:
            mock_service = Mock()
            mock_service.evaluate_request.return_value = (False, "Rate limit exceeded")
            mock_service_class.return_value = mock_service

            response = lambda_handler(event, None)

            assert response['statusCode'] == 403
            body = json.loads(response['body'])
            assert body['allowed'] is False
            assert body['reason'] == "Rate limit exceeded"
```

**Test Step 3.4:**

```bash
cd governance/lambda
pip install pytest pytest-mock

# Run unit tests
python -m pytest tests/unit/ -v

# Check coverage
python -m pytest tests/unit/ --cov=handler --cov-report=html
```

## Acceptance Criteria

- [ ] Lambda function deploys successfully
- [ ] DynamoDB table created with proper schema
- [ ] Default policies loaded correctly
- [ ] Governance API returns proper responses
- [ ] Policy evaluation works for allowed requests
- [ ] Policy evaluation denies unauthorized requests
- [ ] Correlation IDs propagated in responses
- [ ] Structured logging implemented
- [ ] Unit tests pass (>80% coverage)
- [ ] Lambda timeout and memory configured properly
- [ ] IAM permissions are minimal and correct

## Rollback Procedure

If governance layer deployment fails:

```bash
cd governance/terraform
terraform destroy

# Or destroy specific resources
terraform destroy -target=aws_lambda_function.governance
terraform destroy -target=aws_dynamodb_table.policies
```

## Testing Script

Create `tasks/test-task-3.sh`:

```bash
#!/bin/bash
set -e

echo "Testing Task 3: Governance Layer"

# Test Lambda function exists
FUNCTION_NAME="${PROJECT_NAME}-governance"
FUNCTION_EXISTS=$(aws lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.State' 2>/dev/null || echo "Failed")

if [ "$FUNCTION_EXISTS" == "Failed" ]; then
    echo "❌ Governance Lambda function not found"
    exit 1
fi
echo "✅ Governance Lambda function exists"

# Test DynamoDB table exists
TABLE_NAME="${PROJECT_NAME}-governance-policies"
TABLE_EXISTS=$(aws dynamodb describe-table --table-name $TABLE_NAME --query 'Table.TableStatus' 2>/dev/null || echo "Failed")

if [ "$TABLE_EXISTS" == "Failed" ]; then
    echo "❌ Governance DynamoDB table not found"
    exit 1
fi
echo "✅ Governance DynamoDB table exists"

# Test governance API - allowed request
RESPONSE=$(aws lambda invoke --function-name $FUNCTION_NAME \
  --payload '{"service": "orbit", "intent": "call_reasoning"}' \
  --query 'Payload' \
  output.json 2>/dev/null)

ALLOWED=$(cat output.json | jq -r '.allowed')
if [ "$ALLOWED" != "true" ]; then
    echo "❌ Governance should allow orbit:call_reasoning"
    cat output.json
    exit 1
fi
echo "✅ Governance allows authorized requests"

# Test governance API - denied request (unknown intent)
RESPONSE=$(aws lambda invoke --function-name $FUNCTION_NAME \
  --payload '{"service": "orbit", "intent": "unknown_intent"}' \
  --query 'Payload' \
  output.json 2>/dev/null)

ALLOWED=$(cat output.json | jq -r '.allowed')
if [ "$ALLOWED" != "false" ]; then
    echo "❌ Governance should deny unknown intents"
    exit 1
fi
echo "✅ Governance denies unauthorized requests"

# Test policies loaded
POLICY_COUNT=$(aws dynamodb scan --table-name $TABLE_NAME --query 'Count')
if [ "$POLICY_COUNT" -lt 1 ]; then
    echo "❌ No policies found in DynamoDB"
    exit 1
fi
echo "✅ Policies loaded in DynamoDB"

# Run unit tests
cd governance/lambda
python -m pytest tests/unit/ -q

echo ""
echo "🎉 Task 3 Governance Layer: PASSED"
```
