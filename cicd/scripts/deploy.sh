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
    
    # Get execution role ARN (required for Fargate)
    EXECUTION_ROLE_ARN=$(aws iam get-role \
        --role-name ${PROJECT_NAME}-ecs-task-execution-role \
        --query 'Role.Arn' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$EXECUTION_ROLE_ARN" ]; then
        echo "ERROR: Execution role ${PROJECT_NAME}-ecs-task-execution-role not found. Please deploy infrastructure first."
        exit 1
    fi
    
    # Get task role ARN
    TASK_ROLE_ARN=$(aws iam get-role \
        --role-name ${PROJECT_NAME}-axon-role \
        --query 'Role.Arn' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$TASK_ROLE_ARN" ]; then
        echo "ERROR: Task role ${PROJECT_NAME}-axon-role not found. Please deploy infrastructure first."
        exit 1
    fi
    
    # Get secret ARN
    SECRET_ARN=$(aws secretsmanager describe-secret \
        --secret-id ${PROJECT_NAME}/axon \
        --query 'ARN' \
        --output text 2>/dev/null || echo "")
    
    # Build secrets array (only if secret exists)
    if [ -n "$SECRET_ARN" ] && [ "$SECRET_ARN" != "None" ]; then
        SECRETS_JSON=",\"secrets\":[{\"name\":\"DATABASE_URL\",\"valueFrom\":\"${SECRET_ARN}:database_url::\"},{\"name\":\"API_KEY\",\"valueFrom\":\"${SECRET_ARN}:api_key::\"}]"
    else
        echo "WARNING: Secret ${PROJECT_NAME}/axon not found. Continuing without secrets..."
        SECRETS_JSON=""
    fi
    
    # Register new task definition with latest image
    AXON_TASK_DEF=$(aws ecs register-task-definition \
        --family ${PROJECT_NAME}-axon \
        --execution-role-arn "$EXECUTION_ROLE_ARN" \
        --task-role-arn "$TASK_ROLE_ARN" \
        --cli-input-json "{\"containerDefinitions\":[{\"name\":\"axon\",\"image\":\"${IMAGE_URI}:latest\",\"essential\":true,\"portMappings\":[{\"containerPort\":8080,\"protocol\":\"tcp\"}],\"environment\":[{\"name\":\"AWS_REGION\",\"value\":\"${AWS_REGION}\"},{\"name\":\"PORT\",\"value\":\"8080\"}]${SECRETS_JSON},\"logConfiguration\":{\"logDriver\":\"awslogs\",\"options\":{\"awslogs-group\":\"/ecs/${PROJECT_NAME}-axon\",\"awslogs-region\":\"${AWS_REGION}\",\"awslogs-stream-prefix\":\"ecs\"}},\"healthCheck\":{\"command\":[\"CMD-SHELL\",\"wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1\"],\"interval\":30,\"timeout\":5,\"retries\":3,\"startPeriod\":60}}],\"networkMode\":\"awsvpc\",\"requiresCompatibilities\":[\"FARGATE\"],\"cpu\":\"256\",\"memory\":\"512\"}" \
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
            --desired-count 2 \
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
    
    # Get execution role ARN (required for Fargate)
    EXECUTION_ROLE_ARN=$(aws iam get-role \
        --role-name ${PROJECT_NAME}-ecs-task-execution-role \
        --query 'Role.Arn' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$EXECUTION_ROLE_ARN" ]; then
        echo "ERROR: Execution role ${PROJECT_NAME}-ecs-task-execution-role not found. Please deploy infrastructure first."
        exit 1
    fi
    
    # Get task role ARN
    TASK_ROLE_ARN=$(aws iam get-role \
        --role-name ${PROJECT_NAME}-orbit-role \
        --query 'Role.Arn' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$TASK_ROLE_ARN" ]; then
        echo "ERROR: Task role ${PROJECT_NAME}-orbit-role not found. Please deploy infrastructure first."
        exit 1
    fi
    
    # Get secret ARN
    SECRET_ARN=$(aws secretsmanager describe-secret \
        --secret-id ${PROJECT_NAME}/orbit \
        --query 'ARN' \
        --output text 2>/dev/null || echo "")
    
    # Build secrets array (only if secret exists)
    if [ -n "$SECRET_ARN" ] && [ "$SECRET_ARN" != "None" ]; then
        SECRETS_JSON=",\"secrets\":[{\"name\":\"DATABASE_URL\",\"valueFrom\":\"${SECRET_ARN}:database_url::\"},{\"name\":\"API_KEY\",\"valueFrom\":\"${SECRET_ARN}:api_key::\"}]"
    else
        echo "WARNING: Secret ${PROJECT_NAME}/orbit not found. Continuing without secrets..."
        SECRETS_JSON=""
    fi
    
    # Get service discovery namespace
    NAMESPACE=$(aws servicediscovery list-namespaces \
        --query "Namespaces[?Name=='${PROJECT_NAME}.local'].Id" \
        --output text 2>/dev/null | head -1 || echo "")
    
    # Register new task definition with latest image
    ORBIT_TASK_DEF=$(aws ecs register-task-definition \
        --family ${PROJECT_NAME}-orbit \
        --execution-role-arn "$EXECUTION_ROLE_ARN" \
        --task-role-arn "$TASK_ROLE_ARN" \
        --cli-input-json "{\"containerDefinitions\":[{\"name\":\"orbit\",\"image\":\"${IMAGE_URI}:latest\",\"essential\":true,\"portMappings\":[{\"containerPort\":8080,\"protocol\":\"tcp\"}],\"environment\":[{\"name\":\"AWS_REGION\",\"value\":\"${AWS_REGION}\"},{\"name\":\"PORT\",\"value\":\"8080\"},{\"name\":\"AXON_SERVICE_URL\",\"value\":\"http://axon.${PROJECT_NAME}.local/reason\"}]${SECRETS_JSON},\"logConfiguration\":{\"logDriver\":\"awslogs\",\"options\":{\"awslogs-group\":\"/ecs/${PROJECT_NAME}-orbit\",\"awslogs-region\":\"${AWS_REGION}\",\"awslogs-stream-prefix\":\"ecs\"}},\"healthCheck\":{\"command\":[\"CMD-SHELL\",\"wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1\"],\"interval\":30,\"timeout\":5,\"retries\":3,\"startPeriod\":60}}],\"networkMode\":\"awsvpc\",\"requiresCompatibilities\":[\"FARGATE\"],\"cpu\":\"256\",\"memory\":\"512\"}" \
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
            --desired-count 2 \
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

