import json
import os
import time
import pytest
from unittest.mock import Mock, patch, MagicMock

# Set environment variable before importing handler
os.environ['POLICY_TABLE_NAME'] = 'test-table'

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

    def test_evaluate_request_time_restriction(self):
        """Test time restriction evaluation."""
        with patch('handler.table') as mock_table, patch('handler.time') as mock_time:
            # Create a proper struct_time mock
            mock_struct = time.struct_time((2024, 1, 1, 10, 0, 0, 0, 1, 0))
            mock_time.gmtime.return_value = mock_struct
            # Mock time.time() to return a float for duration calculation
            mock_time.time.side_effect = [1000.0, 1000.001]  # start_time, end_time
            mock_table.get_item.return_value = {
                'Item': {
                    'service': 'orbit',
                    'intent': 'call_reasoning',
                    'enabled': True,
                    'time_restrictions': {
                        'allowed_hours': [9, 10, 11]
                    }
                }
            }

            service = GovernanceService()
            allowed, reason = service.evaluate_request('orbit', 'call_reasoning')

            assert allowed is True

    def test_evaluate_request_time_restriction_denied(self):
        """Test time restriction denial."""
        with patch('handler.table') as mock_table, patch('handler.time') as mock_time:
            # Create a proper struct_time mock for hour 5 (outside allowed window)
            mock_struct = time.struct_time((2024, 1, 1, 5, 0, 0, 0, 1, 0))
            mock_time.gmtime.return_value = mock_struct
            # Mock time.time() to return a float for duration calculation
            mock_time.time.side_effect = [1000.0, 1000.001]  # start_time, end_time
            mock_table.get_item.return_value = {
                'Item': {
                    'service': 'orbit',
                    'intent': 'call_reasoning',
                    'enabled': True,
                    'time_restrictions': {
                        'allowed_hours': [9, 10, 11]
                    }
                }
            }

            service = GovernanceService()
            allowed, reason = service.evaluate_request('orbit', 'call_reasoning')

            assert allowed is False
            assert "outside allowed time window" in reason

    def test_evaluate_request_condition_check(self):
        """Test condition evaluation."""
        with patch('handler.table') as mock_table:
            mock_table.get_item.return_value = {
                'Item': {
                    'service': 'orbit',
                    'intent': 'call_reasoning',
                    'enabled': True,
                    'conditions': [
                        {
                            'type': 'context_check',
                            'field': 'user_type',
                            'operator': 'not_equals',
                            'value': 'blocked'
                        }
                    ]
                }
            }

            service = GovernanceService()
            allowed, reason = service.evaluate_request('orbit', 'call_reasoning', {'user_type': 'active'})

            assert allowed is True

    def test_evaluate_request_condition_failed(self):
        """Test condition failure."""
        with patch('handler.table') as mock_table:
            mock_table.get_item.return_value = {
                'Item': {
                    'service': 'orbit',
                    'intent': 'call_reasoning',
                    'enabled': True,
                    'conditions': [
                        {
                            'type': 'context_check',
                            'field': 'user_type',
                            'operator': 'not_equals',
                            'value': 'blocked',
                            'description': 'User must not be blocked'
                        }
                    ]
                }
            }

            service = GovernanceService()
            allowed, reason = service.evaluate_request('orbit', 'call_reasoning', {'user_type': 'blocked'})

            assert allowed is False
            assert "Condition not met" in reason


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
            assert body['service'] == 'orbit'
            assert body['intent'] == 'call_reasoning'

    def test_lambda_handler_with_body_string(self):
        """Test lambda handler with body as string."""
        event = {
            'body': json.dumps({
                'service': 'orbit',
                'intent': 'call_reasoning'
            })
        }

        with patch('handler.GovernanceService') as mock_service_class:
            mock_service = Mock()
            mock_service.evaluate_request.return_value = (True, "Request authorized")
            mock_service_class.return_value = mock_service

            response = lambda_handler(event, None)

            assert response['statusCode'] == 200
            body = json.loads(response['body'])
            assert body['allowed'] is True

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
        assert 'Missing required fields' in body['error']

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

    def test_lambda_handler_json_decode_error(self):
        """Test lambda handler with invalid JSON."""
        event = {
            'body': 'invalid json{'
        }

        response = lambda_handler(event, None)

        assert response['statusCode'] == 400
        body = json.loads(response['body'])
        assert 'error' in body

    def test_lambda_handler_correlation_id(self):
        """Test correlation ID propagation."""
        event = {
            'service': 'orbit',
            'intent': 'call_reasoning',
            'headers': {
                'X-Correlation-ID': 'test-correlation-id-123'
            }
        }

        with patch('handler.GovernanceService') as mock_service_class:
            mock_service = Mock()
            mock_service.evaluate_request.return_value = (True, "Request authorized")
            mock_service_class.return_value = mock_service

            response = lambda_handler(event, None)

            assert response['headers']['X-Correlation-ID'] == 'test-correlation-id-123'
            body = json.loads(response['body'])
            assert body['correlation_id'] == 'test-correlation-id-123'

    def test_lambda_handler_exception(self):
        """Test lambda handler exception handling."""
        event = {
            'service': 'orbit',
            'intent': 'call_reasoning'
        }

        with patch('handler.GovernanceService') as mock_service_class:
            mock_service_class.side_effect = Exception("Unexpected error")

            response = lambda_handler(event, None)

            assert response['statusCode'] == 500
            body = json.loads(response['body'])
            assert 'error' in body

