import json
import logging
import os
import time
from decimal import Decimal
from typing import Dict, Any, Tuple

import boto3

# Configure structured JSON logging
logging.basicConfig(
    level=logging.INFO,
    format='{"time": "%(asctime)s", "level": "%(levelname)s", "message": "%(message)s", "service": "governance"}',
    datefmt='%Y-%m-%dT%H:%M:%S'
)
logger = logging.getLogger(__name__)

# Initialize AWS clients
# Set default region if not specified (required for boto3)
aws_region = os.environ.get('AWS_REGION') or os.environ.get('AWS_DEFAULT_REGION') or 'us-east-1'
dynamodb = boto3.resource('dynamodb', region_name=aws_region)
table_name = os.environ.get('POLICY_TABLE_NAME')
if table_name:
    table = dynamodb.Table(table_name)
else:
    table = None
    logger.warning("POLICY_TABLE_NAME not set, governance will not work")


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
                logger.warning(f'No policy found for service={service}, intent={intent}')
                return False, f"No policy defined for {service}:{intent}"

            # Evaluate policy
            allowed, reason = self._evaluate_policy(policy, context or {})

            duration = time.time() - start_time
            logger.info(f'GOVERNANCE_EVALUATION service={service} intent={intent} allowed={allowed} duration={duration:.3f}s')

            return allowed, reason

        except Exception as e:
            logger.error(f'Governance evaluation failed: {str(e)}')
            return False, "Governance evaluation error"

    def _get_policy(self, service: str, intent: str) -> Dict[str, Any]:
        """Retrieve policy from DynamoDB."""
        if not self.table:
            logger.error("DynamoDB table not initialized")
            return None

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
            logger.error(f'Failed to retrieve policy: {str(e)}')
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
    # Extract correlation ID from various event formats
    correlation_id = 'unknown'
    if isinstance(event, dict):
        if 'headers' in event and isinstance(event['headers'], dict):
            correlation_id = event['headers'].get('X-Correlation-ID', 'unknown')
        elif 'X-Correlation-ID' in event:
            correlation_id = event['X-Correlation-ID']
        elif 'correlation_id' in event:
            correlation_id = event['correlation_id']

    logger.info(f'GOVERNANCE_REQUEST correlation_id={correlation_id} event={json.dumps(event)}')

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

        logger.info(f'GOVERNANCE_RESPONSE correlation_id={correlation_id} allowed={allowed} reason={reason}')

        return {
            'statusCode': status_code,
            'headers': {
                'Content-Type': 'application/json',
                'X-Correlation-ID': correlation_id
            },
            'body': json.dumps(response_body, default=str)
        }

    except json.JSONDecodeError as e:
        logger.error(f'JSON decode error correlation_id={correlation_id} error={str(e)}')
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
        logger.error(f'Unexpected error correlation_id={correlation_id} error={str(e)}')
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

