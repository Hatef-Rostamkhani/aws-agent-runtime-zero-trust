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

if [ -z "$PREVIOUS_AXON_TASK" ] && [ -z "$PREVIOUS_ORBIT_TASK" ]; then
    echo "No previous task definitions found. Cannot rollback."
    exit 1
fi

if [ -n "$PREVIOUS_AXON_TASK" ]; then
    echo "Rolling back Axon to $PREVIOUS_AXON_TASK"
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service ${PROJECT_NAME}-axon \
        --task-definition $PREVIOUS_AXON_TASK \
        --force-new-deployment > /dev/null
fi

if [ -n "$PREVIOUS_ORBIT_TASK" ]; then
    echo "Rolling back Orbit to $PREVIOUS_ORBIT_TASK"
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service ${PROJECT_NAME}-orbit \
        --task-definition $PREVIOUS_ORBIT_TASK \
        --force-new-deployment > /dev/null
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

