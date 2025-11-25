#!/bin/bash

set -e

PROJECT_NAME=${1:-agent-runtime}
AWS_REGION=${2:-us-east-1}
CLUSTER_NAME="${PROJECT_NAME}-cluster"

echo "Running smoke tests for $PROJECT_NAME..."

# Get ALB DNS name and check if it's internal
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?contains(LoadBalancerName, '${PROJECT_NAME}')].DNSName" \
    --output text 2>/dev/null | head -n1 || echo "")

ALB_SCHEME=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?contains(LoadBalancerName, '${PROJECT_NAME}')].Scheme" \
    --output text 2>/dev/null | head -n1 || echo "")

# If ALB is internal or not found, use ECS service health checks
if [ -z "$ALB_DNS" ] || [ "$ALB_SCHEME" = "internal" ]; then
    echo "ALB is internal or not accessible. Using ECS service health checks for smoke tests..."
    
    # Wait for services to stabilize
    echo "Waiting for services to stabilize..."
    aws ecs wait services-stable \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-axon ${PROJECT_NAME}-orbit \
        2>/dev/null || true
    
    # Check ECS service health
    AXON_RUNNING=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-axon \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null || echo "0")
    
    AXON_DESIRED=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-axon \
        --query 'services[0].desiredCount' \
        --output text 2>/dev/null || echo "0")
    
    ORBIT_RUNNING=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-orbit \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null || echo "0")
    
    ORBIT_DESIRED=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-orbit \
        --query 'services[0].desiredCount' \
        --output text 2>/dev/null || echo "0")
    
    # Check target group health
    AXON_TG_ARN=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-axon \
        --query 'services[0].loadBalancers[0].targetGroupArn' \
        --output text 2>/dev/null || echo "")
    
    ORBIT_TG_ARN=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-orbit \
        --query 'services[0].loadBalancers[0].targetGroupArn' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$AXON_TG_ARN" ]; then
        AXON_TG_HEALTHY=$(aws elbv2 describe-target-health \
            --target-group-arn "$AXON_TG_ARN" \
            --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`].TargetHealth.State' \
            --output text 2>/dev/null | wc -w || echo "0")
    else
        AXON_TG_HEALTHY="0"
    fi
    
    if [ -n "$ORBIT_TG_ARN" ]; then
        ORBIT_TG_HEALTHY=$(aws elbv2 describe-target-health \
            --target-group-arn "$ORBIT_TG_ARN" \
            --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`].TargetHealth.State' \
            --output text 2>/dev/null | wc -w || echo "0")
    else
        ORBIT_TG_HEALTHY="0"
    fi
    
    echo "ECS Service Status:"
    echo "  Axon: Running=$AXON_RUNNING/$AXON_DESIRED, Target Group Healthy=$AXON_TG_HEALTHY"
    echo "  Orbit: Running=$ORBIT_RUNNING/$ORBIT_DESIRED, Target Group Healthy=$ORBIT_TG_HEALTHY"
    
    # Verify services are healthy
    FAILED=0
    
    if [ "$AXON_RUNNING" -lt "$AXON_DESIRED" ] || [ "$AXON_DESIRED" -eq 0 ]; then
        echo "❌ Axon service is not healthy (Running: $AXON_RUNNING, Desired: $AXON_DESIRED)"
        FAILED=1
    else
        echo "✅ Axon service is running"
    fi
    
    if [ "$AXON_TG_HEALTHY" -eq 0 ] && [ -n "$AXON_TG_ARN" ]; then
        echo "⚠️  Axon target group has no healthy targets"
        FAILED=1
    elif [ -n "$AXON_TG_ARN" ]; then
        echo "✅ Axon target group has $AXON_TG_HEALTHY healthy target(s)"
    fi
    
    if [ "$ORBIT_RUNNING" -lt "$ORBIT_DESIRED" ] || [ "$ORBIT_DESIRED" -eq 0 ]; then
        echo "❌ Orbit service is not healthy (Running: $ORBIT_RUNNING, Desired: $ORBIT_DESIRED)"
        FAILED=1
    else
        echo "✅ Orbit service is running"
    fi
    
    if [ "$ORBIT_TG_HEALTHY" -eq 0 ] && [ -n "$ORBIT_TG_ARN" ]; then
        echo "⚠️  Orbit target group has no healthy targets"
        FAILED=1
    elif [ -n "$ORBIT_TG_ARN" ]; then
        echo "✅ Orbit target group has $ORBIT_TG_HEALTHY healthy target(s)"
    fi
    
    if [ $FAILED -eq 1 ]; then
        echo "❌ Smoke tests failed"
        exit 1
    fi
    
    echo "✅ All smoke tests passed (ECS service health checks)"
    exit 0
fi

# ALB is public - use HTTP endpoint tests
BASE_URL="http://${ALB_DNS}"
FAILED=0

# Test Axon reason endpoint (matches listener rule: /reason*)
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

# Test Orbit health endpoint (matches listener rule: /health)
echo "Testing Orbit health endpoint..."
ORBIT_HEALTH=$(curl -s -w "\n%{http_code}" "${BASE_URL}/health" || echo "000")
HTTP_CODE=$(echo "$ORBIT_HEALTH" | tail -n1)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Orbit health check passed"
    echo "$ORBIT_HEALTH" | head -n1 | jq '.' 2>/dev/null || echo "$ORBIT_HEALTH" | head -n1
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

