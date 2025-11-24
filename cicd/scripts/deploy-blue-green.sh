#!/bin/bash

set -e

SERVICE_NAME=${1:-all}
PROJECT_NAME=${2:-agent-runtime}
AWS_REGION=${3:-us-east-1}
CLUSTER_NAME="${PROJECT_NAME}-cluster"

echo "Starting blue-green deployment for $SERVICE_NAME..."

# Get current service state
if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "axon" ]; then
    CURRENT_AXON_TASK=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-axon \
        --query 'services[0].taskDefinition' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$CURRENT_AXON_TASK" ]; then
        echo "Current Axon task definition: $CURRENT_AXON_TASK"
        
        # Save current task definition for rollback
        aws ssm put-parameter \
            --name "/${PROJECT_NAME}/axon/previous-task-def" \
            --value "$CURRENT_AXON_TASK" \
            --type "String" \
            --overwrite > /dev/null 2>&1 || true
    fi
fi

if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "orbit" ]; then
    CURRENT_ORBIT_TASK=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-orbit \
        --query 'services[0].taskDefinition' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$CURRENT_ORBIT_TASK" ]; then
        echo "Current Orbit task definition: $CURRENT_ORBIT_TASK"
        
        # Save current task definition for rollback
        aws ssm put-parameter \
            --name "/${PROJECT_NAME}/orbit/previous-task-def" \
            --value "$CURRENT_ORBIT_TASK" \
            --type "String" \
            --overwrite > /dev/null 2>&1 || true
    fi
fi

# Deploy new version (green) - ECS handles rolling deployment
echo "Deploying new version..."
export PROJECT_NAME=$PROJECT_NAME
export AWS_REGION=$AWS_REGION
./deploy.sh production $SERVICE_NAME

# Run health checks
echo "Running health checks..."
if ./health-check.sh $PROJECT_NAME $AWS_REGION; then
    echo "Health checks passed. Deployment successful."
else
    echo "Health checks failed. Rolling back..."
    ./rollback.sh $PROJECT_NAME $AWS_REGION
    exit 1
fi

echo "Blue-green deployment completed successfully"

