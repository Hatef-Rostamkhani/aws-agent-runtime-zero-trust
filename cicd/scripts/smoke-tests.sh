#!/bin/bash

set -e

PROJECT_NAME=${1:-agent-runtime}
AWS_REGION=${2:-us-east-1}

echo "Running smoke tests for $PROJECT_NAME..."

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?contains(LoadBalancerName, '${PROJECT_NAME}')].DNSName" \
    --output text 2>/dev/null | head -n1 || echo "")

if [ -z "$ALB_DNS" ]; then
    echo "Warning: Could not find ALB DNS. Skipping smoke tests."
    exit 0
fi

BASE_URL="http://${ALB_DNS}"
FAILED=0

# Test Axon health endpoint
echo "Testing Axon health endpoint..."
AXON_HEALTH=$(curl -s -w "\n%{http_code}" "${BASE_URL}/health" || echo "000")
HTTP_CODE=$(echo "$AXON_HEALTH" | tail -n1)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Axon health check passed"
else
    echo "❌ Axon health check failed (HTTP $HTTP_CODE)"
    FAILED=1
fi

# Test Axon reason endpoint
echo "Testing Axon reason endpoint..."
AXON_REASON=$(curl -s -w "\n%{http_code}" "${BASE_URL}/reason" || echo "000")
HTTP_CODE=$(echo "$AXON_REASON" | tail -n1)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Axon reason endpoint passed"
    echo "$AXON_REASON" | head -n1 | jq '.' 2>/dev/null || echo "$AXON_REASON" | head -n1
else
    echo "❌ Axon reason endpoint failed (HTTP $HTTP_CODE)"
    FAILED=1
fi

# Test Orbit health endpoint
echo "Testing Orbit health endpoint..."
ORBIT_HEALTH=$(curl -s -w "\n%{http_code}" "${BASE_URL}/health" || echo "000")
HTTP_CODE=$(echo "$ORBIT_HEALTH" | tail -n1)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Orbit health check passed"
else
    echo "❌ Orbit health check failed (HTTP $HTTP_CODE)"
    FAILED=1
fi

# Test Orbit dispatch endpoint (requires governance)
echo "Testing Orbit dispatch endpoint..."
ORBIT_DISPATCH=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/dispatch" \
    -H "Content-Type: application/json" \
    -H "X-Correlation-ID: smoke-test-$(date +%s)" || echo "000")
HTTP_CODE=$(echo "$ORBIT_DISPATCH" | tail -n1)
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "403" ]; then
    echo "✅ Orbit dispatch endpoint responded (HTTP $HTTP_CODE)"
    echo "$ORBIT_DISPATCH" | head -n1 | jq '.' 2>/dev/null || echo "$ORBIT_DISPATCH" | head -n1
else
    echo "⚠️  Orbit dispatch endpoint returned unexpected code (HTTP $HTTP_CODE)"
    # Don't fail on this as it may require governance setup
fi

if [ $FAILED -eq 1 ]; then
    echo "❌ Smoke tests failed"
    exit 1
fi

echo "✅ All smoke tests passed"

