#!/bin/bash

set -e

PROJECT_NAME=${1:-agent-runtime}
AWS_REGION=${2:-us-east-1}
CLUSTER_NAME="${PROJECT_NAME}-cluster"
MAX_RETRIES=30
RETRY_INTERVAL=10

echo "Running health checks for $PROJECT_NAME..."

# Get ALB DNS name from Terraform output or AWS
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?contains(LoadBalancerName, '${PROJECT_NAME}')].DNSName" \
    --output text 2>/dev/null | head -n1 || echo "")

if [ -z "$ALB_DNS" ]; then
    echo "Warning: Could not find ALB DNS. Skipping HTTP health checks."
    # Fallback: Check ECS service health
    AXON_HEALTHY=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-axon \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null || echo "0")
    
    ORBIT_HEALTHY=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-orbit \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$AXON_HEALTHY" -gt 0 ] && [ "$ORBIT_HEALTHY" -gt 0 ]; then
        echo "✅ Services are running (Axon: $AXON_HEALTHY, Orbit: $ORBIT_HEALTHY tasks)"
        exit 0
    else
        echo "❌ Services are not healthy (Axon: $AXON_HEALTHY, Orbit: $ORBIT_HEALTHY tasks)"
        exit 1
    fi
fi

# Health check function
check_endpoint() {
    local endpoint=$1
    local service=$2
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$endpoint" || echo "000")
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo "✅ $service health check passed"
            return 0
        fi
        
        retries=$((retries + 1))
        if [ $retries -lt $MAX_RETRIES ]; then
            echo "⏳ $service health check failed (HTTP $HTTP_CODE). Retrying in ${RETRY_INTERVAL}s... ($retries/$MAX_RETRIES)"
            sleep $RETRY_INTERVAL
        fi
    done
    
    echo "❌ $service health check failed after $MAX_RETRIES retries"
    return 1
}

# Check Axon health
AXON_ENDPOINT="http://${ALB_DNS}/health"
check_endpoint "$AXON_ENDPOINT" "Axon" || exit 1

# Check Orbit health
ORBIT_ENDPOINT="http://${ALB_DNS}/health"
check_endpoint "$ORBIT_ENDPOINT" "Orbit" || exit 1

echo "✅ All health checks passed"

