#!/bin/bash

set -e

PROJECT_NAME=${1:-agent-runtime}
AWS_REGION=${2:-us-east-1}
CLUSTER_NAME="${PROJECT_NAME}-cluster"

echo "Starting rollback for $PROJECT_NAME..."

# Get previous task definitions from SSM Parameter Store
PREVIOUS_AXON_TASK=$(aws ssm get-parameter \
    --name "/${PROJECT_NAME}/axon/previous-task-def" \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || echo "")

PREVIOUS_ORBIT_TASK=$(aws ssm get-parameter \
    --name "/${PROJECT_NAME}/orbit/previous-task-def" \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || echo "")

# Filter out "None" and empty values
if [ "$PREVIOUS_AXON_TASK" = "None" ] || [ -z "$PREVIOUS_AXON_TASK" ]; then
    PREVIOUS_AXON_TASK=""
fi
if [ "$PREVIOUS_ORBIT_TASK" = "None" ] || [ -z "$PREVIOUS_ORBIT_TASK" ]; then
    PREVIOUS_ORBIT_TASK=""
fi

if [ -z "$PREVIOUS_AXON_TASK" ] && [ -z "$PREVIOUS_ORBIT_TASK" ]; then
    echo "No previous task definitions found. This may be a first deployment or the services don't exist yet."
    exit 0
fi

if [ -n "$PREVIOUS_AXON_TASK" ]; then
    # Check if service exists before rolling back
    SERVICE_EXISTS=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-axon \
        --query 'services[0].status' \
        --output text 2>/dev/null || echo "INACTIVE")
    
    if [ "$SERVICE_EXISTS" = "ACTIVE" ]; then
        echo "Rolling back Axon to $PREVIOUS_AXON_TASK"
        aws ecs update-service \
            --cluster $CLUSTER_NAME \
            --service ${PROJECT_NAME}-axon \
            --task-definition $PREVIOUS_AXON_TASK \
            --force-new-deployment > /dev/null
    else
        echo "Service ${PROJECT_NAME}-axon does not exist. Skipping rollback."
    fi
else
    echo "No previous Axon task definition to rollback to"
fi

if [ -n "$PREVIOUS_ORBIT_TASK" ]; then
    # Check if service exists before rolling back
    SERVICE_EXISTS=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-orbit \
        --query 'services[0].status' \
        --output text 2>/dev/null || echo "INACTIVE")
    
    if [ "$SERVICE_EXISTS" = "ACTIVE" ]; then
        echo "Rolling back Orbit to $PREVIOUS_ORBIT_TASK"
        aws ecs update-service \
            --cluster $CLUSTER_NAME \
            --service ${PROJECT_NAME}-orbit \
            --task-definition $PREVIOUS_ORBIT_TASK \
            --force-new-deployment > /dev/null
    else
        echo "Service ${PROJECT_NAME}-orbit does not exist. Skipping rollback."
    fi
else
    echo "No previous Orbit task definition to rollback to"
fi

# Wait for services to stabilize
SERVICES=""
[ -n "$PREVIOUS_AXON_TASK" ] && SERVICES="${SERVICES} ${PROJECT_NAME}-axon"
[ -n "$PREVIOUS_ORBIT_TASK" ] && SERVICES="${SERVICES} ${PROJECT_NAME}-orbit"

if [ -n "$SERVICES" ]; then
    echo "Waiting for services to stabilize..."
    aws ecs wait services-stable \
        --cluster $CLUSTER_NAME \
        --services $SERVICES
fi

echo "Rollback completed"

