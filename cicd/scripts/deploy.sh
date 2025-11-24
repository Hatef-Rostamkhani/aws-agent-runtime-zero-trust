#!/bin/bash

set -e

ENVIRONMENT=${1:-production}
SERVICE_NAME=${2:-all}
PROJECT_NAME=${PROJECT_NAME:-agent-runtime}
AWS_REGION=${AWS_REGION:-us-east-1}
CLUSTER_NAME="${PROJECT_NAME}-cluster"

echo "Deploying $SERVICE_NAME to $ENVIRONMENT..."

# Update ECS task definitions
if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "axon" ]; then
    echo "Updating Axon task definition..."
    
    # Get current task definition
    CURRENT_TASK_DEF=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-axon \
        --query 'services[0].taskDefinition' \
        --output text 2>/dev/null || echo "")
    
    # Save current task definition for rollback
    if [ -n "$CURRENT_TASK_DEF" ]; then
        aws ssm put-parameter \
            --name "/${PROJECT_NAME}/axon/previous-task-def" \
            --value "$CURRENT_TASK_DEF" \
            --type "String" \
            --overwrite > /dev/null 2>&1 || true
    fi
    
    # Get latest image URI
    IMAGE_URI=$(aws ecr describe-repositories \
        --repository-names ${PROJECT_NAME}/axon \
        --query 'repositories[0].repositoryUri' \
        --output text)
    
    # Register new task definition with latest image
    AXON_TASK_DEF=$(aws ecs register-task-definition \
        --family ${PROJECT_NAME}-axon \
        --cli-input-json "{\"containerDefinitions\":[{\"name\":\"axon\",\"image\":\"${IMAGE_URI}:latest\",\"essential\":true,\"portMappings\":[{\"containerPort\":80,\"protocol\":\"tcp\"}]}],\"networkMode\":\"awsvpc\",\"requiresCompatibilities\":[\"FARGATE\"],\"cpu\":\"256\",\"memory\":\"512\"}" \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    
    # Check if service exists before updating
    SERVICE_EXISTS=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-axon \
        --query 'services[0].status' \
        --output text 2>/dev/null || echo "INACTIVE")
    
    if [ "$SERVICE_EXISTS" = "ACTIVE" ]; then
        echo "Updating Axon service with new task definition..."
        aws ecs update-service \
            --cluster $CLUSTER_NAME \
            --service ${PROJECT_NAME}-axon \
            --task-definition $AXON_TASK_DEF \
            --force-new-deployment > /dev/null
    else
        echo "ERROR: Service ${PROJECT_NAME}-axon does not exist. Please deploy infrastructure first."
        exit 1
    fi
fi

if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "orbit" ]; then
    echo "Updating Orbit task definition..."
    
    # Get current task definition
    CURRENT_TASK_DEF=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-orbit \
        --query 'services[0].taskDefinition' \
        --output text 2>/dev/null || echo "")
    
    # Save current task definition for rollback
    if [ -n "$CURRENT_TASK_DEF" ]; then
        aws ssm put-parameter \
            --name "/${PROJECT_NAME}/orbit/previous-task-def" \
            --value "$CURRENT_TASK_DEF" \
            --type "String" \
            --overwrite > /dev/null 2>&1 || true
    fi
    
    # Get latest image URI
    IMAGE_URI=$(aws ecr describe-repositories \
        --repository-names ${PROJECT_NAME}/orbit \
        --query 'repositories[0].repositoryUri' \
        --output text)
    
    # Register new task definition with latest image
    ORBIT_TASK_DEF=$(aws ecs register-task-definition \
        --family ${PROJECT_NAME}-orbit \
        --cli-input-json "{\"containerDefinitions\":[{\"name\":\"orbit\",\"image\":\"${IMAGE_URI}:latest\",\"essential\":true,\"portMappings\":[{\"containerPort\":80,\"protocol\":\"tcp\"}]}],\"networkMode\":\"awsvpc\",\"requiresCompatibilities\":[\"FARGATE\"],\"cpu\":\"256\",\"memory\":\"512\"}" \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    
    # Check if service exists before updating
    SERVICE_EXISTS=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services ${PROJECT_NAME}-orbit \
        --query 'services[0].status' \
        --output text 2>/dev/null || echo "INACTIVE")
    
    if [ "$SERVICE_EXISTS" = "ACTIVE" ]; then
        echo "Updating Orbit service with new task definition..."
        aws ecs update-service \
            --cluster $CLUSTER_NAME \
            --service ${PROJECT_NAME}-orbit \
            --task-definition $ORBIT_TASK_DEF \
            --force-new-deployment > /dev/null
    else
        echo "ERROR: Service ${PROJECT_NAME}-orbit does not exist. Please deploy infrastructure first."
        exit 1
    fi
fi

echo "Waiting for services to stabilize..."
SERVICES=""
[ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "axon" ] && SERVICES="${SERVICES} ${PROJECT_NAME}-axon"
[ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "orbit" ] && SERVICES="${SERVICES} ${PROJECT_NAME}-orbit"

if [ -n "$SERVICES" ]; then
    aws ecs wait services-stable \
        --cluster $CLUSTER_NAME \
        --services $SERVICES
fi

echo "Deployment completed successfully"

