#!/bin/bash

set -e

PROJECT_NAME=${1:-agent-runtime}
AWS_REGION=${2:-us-east-1}
SERVICE_NAME=${3:-all}
CLUSTER_NAME="${PROJECT_NAME}-cluster"
MAX_RETRIES=30
RETRY_INTERVAL=10

echo "Running health checks for $PROJECT_NAME (service: $SERVICE_NAME)..."

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
    
    # Build list of services to check based on SERVICE_NAME parameter
    SERVICES_TO_CHECK=""
    [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "axon" ] && SERVICES_TO_CHECK="${SERVICES_TO_CHECK} ${PROJECT_NAME}-axon"
    [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "orbit" ] && SERVICES_TO_CHECK="${SERVICES_TO_CHECK} ${PROJECT_NAME}-orbit"
    
    if [ -z "$SERVICES_TO_CHECK" ]; then
        echo "No services to check. Exiting."
        exit 0
    fi
    
    # Wait for services to stabilize
    echo "Waiting for services to stabilize..."
    aws ecs wait services-stable \
        --cluster $CLUSTER_NAME \
        --services $SERVICES_TO_CHECK \
        2>/dev/null || true
    
    FAILED=0
    
    # Check Axon if needed
    if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "axon" ]; then
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
        
        AXON_TG_ARN=$(aws ecs describe-services \
            --cluster $CLUSTER_NAME \
            --services ${PROJECT_NAME}-axon \
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
        
        echo "  Axon: Running=$AXON_RUNNING/$AXON_DESIRED, Target Group Healthy=$AXON_TG_HEALTHY"
        
        # Only check health if desired count > 0
        if [ "$AXON_DESIRED" -gt 0 ]; then
            if [ "$AXON_RUNNING" -lt "$AXON_DESIRED" ]; then
                echo "❌ Axon service is not healthy (Running: $AXON_RUNNING, Desired: $AXON_DESIRED)"
                FAILED=1
            elif [ "$AXON_TG_HEALTHY" -eq 0 ] && [ -n "$AXON_TG_ARN" ]; then
                echo "❌ Axon target group has no healthy targets"
                FAILED=1
            else
                echo "✅ Axon service is healthy"
            fi
        else
            echo "⚠️  Axon service has desired count 0 (not deployed), skipping health check"
        fi
    fi
    
    # Check Orbit if needed
    if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "orbit" ]; then
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
        
        ORBIT_TG_ARN=$(aws ecs describe-services \
            --cluster $CLUSTER_NAME \
            --services ${PROJECT_NAME}-orbit \
            --query 'services[0].loadBalancers[0].targetGroupArn' \
            --output text 2>/dev/null || echo "")
        
        if [ -n "$ORBIT_TG_ARN" ]; then
            ORBIT_TG_HEALTHY=$(aws elbv2 describe-target-health \
                --target-group-arn "$ORBIT_TG_ARN" \
                --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`].TargetHealth.State' \
                --output text 2>/dev/null | wc -w || echo "0")
        else
            ORBIT_TG_HEALTHY="0"
        fi
        
        echo "  Orbit: Running=$ORBIT_RUNNING/$ORBIT_DESIRED, Target Group Healthy=$ORBIT_TG_HEALTHY"
        
        # Only check health if desired count > 0
        if [ "$ORBIT_DESIRED" -gt 0 ]; then
            if [ "$ORBIT_RUNNING" -lt "$ORBIT_DESIRED" ]; then
                echo "❌ Orbit service is not healthy (Running: $ORBIT_RUNNING, Desired: $ORBIT_DESIRED)"
                FAILED=1
            elif [ "$ORBIT_TG_HEALTHY" -eq 0 ] && [ -n "$ORBIT_TG_ARN" ]; then
                echo "❌ Orbit target group has no healthy targets"
                FAILED=1
            else
                echo "✅ Orbit service is healthy"
            fi
        else
            echo "⚠️  Orbit service has desired count 0 (not deployed), skipping health check"
        fi
    fi
    
    if [ $FAILED -eq 1 ]; then
        echo "❌ Services are not fully healthy"
        exit 1
    else
        echo "✅ All checked services are healthy"
        exit 0
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

# Check services based on SERVICE_NAME parameter
if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "axon" ]; then
    # Check Axon health (using /reason endpoint as per listener rule)
    AXON_ENDPOINT="http://${ALB_DNS}/reason"
    check_endpoint "$AXON_ENDPOINT" "Axon" || exit 1
fi

if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "orbit" ]; then
    # Check Orbit health (using /health endpoint as per listener rule)
    ORBIT_ENDPOINT="http://${ALB_DNS}/health"
    check_endpoint "$ORBIT_ENDPOINT" "Orbit" || exit 1
fi

echo "✅ All health checks passed"

