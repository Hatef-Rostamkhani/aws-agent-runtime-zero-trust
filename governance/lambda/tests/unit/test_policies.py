import pytest
from policies import PolicyManager


class TestPolicyManager:
    def test_create_default_policies(self):
        """Test default policy creation."""
        policies = PolicyManager.create_default_policies()

        assert len(policies) >= 2
        assert any(p['service'] == 'orbit' and p['intent'] == 'call_reasoning' for p in policies)
        assert any(p['service'] == 'orbit' and p['intent'] == 'call_metrics' for p in policies)

    def test_validate_policy_valid(self):
        """Test policy validation with valid policy."""
        policy = {
            'service': 'orbit',
            'intent': 'call_reasoning',
            'enabled': True
        }

        valid, message = PolicyManager.validate_policy(policy)
        assert valid is True
        assert "valid" in message.lower()

    def test_validate_policy_missing_service(self):
        """Test policy validation with missing service field."""
        policy = {
            'intent': 'call_reasoning',
            'enabled': True
        }

        valid, message = PolicyManager.validate_policy(policy)
        assert valid is False
        assert 'service' in message.lower()

    def test_validate_policy_missing_intent(self):
        """Test policy validation with missing intent field."""
        policy = {
            'service': 'orbit',
            'enabled': True
        }

        valid, message = PolicyManager.validate_policy(policy)
        assert valid is False
        assert 'intent' in message.lower()

    def test_validate_policy_missing_enabled(self):
        """Test policy validation with missing enabled field."""
        policy = {
            'service': 'orbit',
            'intent': 'call_reasoning'
        }

        valid, message = PolicyManager.validate_policy(policy)
        assert valid is False
        assert 'enabled' in message.lower()

    def test_validate_policy_invalid_enabled_type(self):
        """Test policy validation with invalid enabled type."""
        policy = {
            'service': 'orbit',
            'intent': 'call_reasoning',
            'enabled': 'true'  # Should be boolean
        }

        valid, message = PolicyManager.validate_policy(policy)
        assert valid is False
        assert 'boolean' in message.lower()

    def test_serialize_policy(self):
        """Test policy serialization."""
        policy = {
            'service': 'orbit',
            'intent': 'call_reasoning',
            'enabled': True,
            'rate_limits': {
                'requests_per_minute': 100,
                'requests_per_hour': 1000
            }
        }

        serialized = PolicyManager.serialize_policy(policy)
        assert isinstance(serialized, str)
        
        # Should be valid JSON
        import json
        deserialized = json.loads(serialized)
        assert deserialized['service'] == 'orbit'

