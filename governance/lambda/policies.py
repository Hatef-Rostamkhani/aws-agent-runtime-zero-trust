"""
Policy management utilities for governance service.
"""

import json
from decimal import Decimal
from typing import Dict, Any, List, Tuple


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
            elif isinstance(obj, bool):
                # Booleans should be kept as-is for DynamoDB
                return obj
            elif isinstance(obj, (int, float)):
                return Decimal(str(obj))
            else:
                return obj

        return json.dumps(convert_to_dynamodb_format(policy), default=str)

