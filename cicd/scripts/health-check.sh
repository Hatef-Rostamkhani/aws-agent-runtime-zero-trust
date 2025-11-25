#!/bin/bash

set -e

PROJECT_NAME=${1:-agent-runtime}
AWS_REGION=${2:-us-east-1}
CLUSTER_NAME="${PROJECT_NAME}-cluster"
MAX_RETRIES=30
RETRY_INTERVAL=10

echo "Running health checks for $PROJECT_NAME..."

# Get ALB DNS name and check if it's internal
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?contains(LoadBalancerName, '${PROJECT_NAME}')].DNSName" \
    --output text 2>/dev/null | head -n1 || echo "")

ALB_SCHEME=$(aws elbv2 describe-load-balancers \
    --query "LoadBalancers[?contains(LoadBalancerName, '${PROJECT_NAME}')].Scheme" \
    --output text 2>/dev/null | head -n1 || echo "")

# If ALB is internal or not found, use ECS service health checks
if [ -z "$ALB_DNS" ] || [ "$ALB_SCHEME" = "internal" ]; then
    echo "ALB is internal or not accessible. Using ECS service health checks..."
    
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
    
    if [ "$AXON_RUNNING" -ge "$AXON_DESIRED" ] && [ "$AXON_DESIRED" -gt 0 ] && \
       [ "$ORBIT_RUNNING" -ge "$ORBIT_DESIRED" ] && [ "$ORBIT_DESIRED" -gt 0 ] && \
       [ "$AXON_TG_HEALTHY" -gt 0 ] && [ "$ORBIT_TG_HEALTHY" -gt 0 ]; then
        echo "✅ All services are healthy"
        exit 0
    else
        echo "❌ Services are not fully healthy"
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

# Check Axon health (using /reason endpoint as per listener rule)
AXON_ENDPOINT="http://${ALB_DNS}/reason"
check_endpoint "$AXON_ENDPOINT" "Axon" || exit 1

# Check Orbit health (using /health endpoint as per listener rule)
ORBIT_ENDPOINT="http://${ALB_DNS}/health"
check_endpoint "$ORBIT_ENDPOINT" "Orbit" || exit 1

echo "✅ All health checks passed"

