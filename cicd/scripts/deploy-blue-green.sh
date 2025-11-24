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
        --output text 2>/dev/null || echo "None")

    if [ "$CURRENT_ORBIT_TASK" != "None" ] && [ -n "$CURRENT_ORBIT_TASK" ]; then
        echo "Current Orbit task definition: $CURRENT_ORBIT_TASK"

        # Save current task definition for rollback
        aws ssm put-parameter \
            --name "/${PROJECT_NAME}/orbit/previous-task-def" \
            --value "$CURRENT_ORBIT_TASK" \
            --type "String" \
            --overwrite > /dev/null 2>&1 || true
    else
        echo "Current Orbit task definition: None (first deployment)"
    fi
fi

# Deploy new version (green) - ECS handles rolling deployment
echo "Deploying new version..."
export PROJECT_NAME=$PROJECT_NAME
export AWS_REGION=$AWS_REGION
# Get the absolute path to the deploy.sh script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/deploy.sh" production $SERVICE_NAME

# Run health checks
echo "Running health checks..."
if "$SCRIPT_DIR/health-check.sh" $PROJECT_NAME $AWS_REGION; then
    echo "Health checks passed. Deployment successful."
else
    echo "Health checks failed. Rolling back..."
    "$SCRIPT_DIR/rollback.sh" $PROJECT_NAME $AWS_REGION
    exit 1
fi

echo "Blue-green deployment completed successfully"

