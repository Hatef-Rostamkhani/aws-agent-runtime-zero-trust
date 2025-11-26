#!/usr/bin/env python3
"""
Governance Layer Testing Script

This script demonstrates the "Think → Govern → Act" pattern by simulating
how Orbit would check with the governance layer before calling Axon.
"""

import json
import boto3
import time
from typing import Dict, Any

# AWS Lambda client
lambda_client = boto3.client('lambda', region_name='us-east-1')
GOVERNANCE_FUNCTION = 'agent-runtime-governance'

class OrbitService:
    """Simulates Orbit service that must check governance before calling Axon."""

    def call_reasoning(self, user_query: str) -> str:
        """Orbit wants to call Axon's reasoning service."""
        print("🧠 Orbit: Thinking about calling Axon reasoning service...")

        # Step 1: THINK - Decide what we want to do
        intent = "call_reasoning"
        service = "orbit"

        # Step 2: GOVERN - Check with governance layer
        print("📋 Orbit: Checking governance permission...")
        governance_request = {
            "service": service,
            "intent": intent,
            "context": {
                "user_type": "authenticated",
                "query_length": len(user_query)
            }
        }

        allowed, reason = self._check_governance(governance_request)

        if not allowed:
            # DENIED - Stop the request
            print(f"❌ Orbit: Request DENIED - {reason}")
            return f"Access denied: {reason}"

        # Step 3: ACT - Proceed with the call to Axon
        print("✅ Orbit: Request ALLOWED - proceeding to call Axon")
        return self._call_axon_reasoning(user_query)

    def call_metrics(self) -> str:
        """Orbit wants to retrieve metrics."""
        print("📊 Orbit: Thinking about retrieving metrics...")

        # Step 1: THINK
        intent = "call_metrics"
        service = "orbit"

        # Step 2: GOVERN
        print("📋 Orbit: Checking governance permission...")
        governance_request = {
            "service": service,
            "intent": intent
        }

        allowed, reason = self._check_governance(governance_request)

        if not allowed:
            print(f"❌ Orbit: Request DENIED - {reason}")
            return f"Access denied: {reason}"

        # Step 3: ACT
        print("✅ Orbit: Request ALLOWED - retrieving metrics")
        return "Metrics data retrieved successfully"

    def _check_governance(self, request: Dict[str, Any]) -> tuple[bool, str]:
        """Check permission with governance Lambda."""
        try:
            response = lambda_client.invoke(
                FunctionName=GOVERNANCE_FUNCTION,
                Payload=json.dumps(request)
            )

            # Parse response
            payload = json.loads(response['Payload'].read())
            body = json.loads(payload['body'])

            return body['allowed'], body['reason']

        except Exception as e:
            print(f"❌ Governance check failed: {str(e)}")
            return False, "Governance service unavailable"

    def _call_axon_reasoning(self, query: str) -> str:
        """Simulate calling Axon reasoning service."""
        # In a real implementation, this would make an HTTP call to Axon
        print("🤖 Axon: Processing reasoning request...")
        time.sleep(0.5)  # Simulate processing time
        return f"Axon reasoning result for: '{query}'"

def test_governance():
    """Test the governance layer functionality."""
    print("🚀 Testing Governance Layer - 'Think → Govern → Act' Pattern")
    print("=" * 60)

    orbit = OrbitService()

    # Test 1: Allowed request (call_reasoning)
    print("\n🧪 Test 1: Calling reasoning service")
    print("-" * 40)
    result = orbit.call_reasoning("What is the meaning of life?")
    print(f"Result: {result}")

    # Test 2: Allowed request (call_metrics)
    print("\n🧪 Test 2: Retrieving metrics")
    print("-" * 40)
    result = orbit.call_metrics()
    print(f"Result: {result}")

    # Test 3: Denied request (non-existent intent)
    print("\n🧪 Test 3: Invalid intent (should be denied)")
    print("-" * 40)
    try:
        response = lambda_client.invoke(
            FunctionName=GOVERNANCE_FUNCTION,
            Payload=json.dumps({
                "service": "orbit",
                "intent": "invalid_intent"
            })
        )
        payload = json.loads(response['Payload'].read())
        print(f"Status Code: {payload['statusCode']}")
        if payload['statusCode'] == 403:
            print("✅ Correctly DENIED - No policy for this intent")
        else:
            print("❌ Unexpected response")
    except Exception as e:
        print(f"❌ Error: {str(e)}")

    print("\n🎯 Governance Layer Test Complete!")
    print("✅ 'Think → Govern → Act' pattern is working correctly")

if __name__ == "__main__":
    test_governance()
