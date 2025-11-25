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
    
    # Build environment variables
    ENV_VARS="[{\"name\":\"AWS_REGION\",\"value\":\"${AWS_REGION}\"},{\"name\":\"PORT\",\"value\":\"8080\"}"
    if [ -n "$SECRET_ARN" ] && [ "$SECRET_ARN" != "None" ]; then
        ENV_VARS="${ENV_VARS},{\"name\":\"AXON_SECRET_ARN\",\"value\":\"${SECRET_ARN}\"}"
    fi
    ENV_VARS="${ENV_VARS}]"
    
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
        --cli-input-json "{\"containerDefinitions\":[{\"name\":\"axon\",\"image\":\"${IMAGE_URI}:latest\",\"essential\":true,\"portMappings\":[{\"containerPort\":8080,\"protocol\":\"tcp\"}],\"environment\":${ENV_VARS}${SECRETS_JSON},\"logConfiguration\":{\"logDriver\":\"awslogs\",\"options\":{\"awslogs-group\":\"/ecs/${PROJECT_NAME}-axon\",\"awslogs-region\":\"${AWS_REGION}\",\"awslogs-stream-prefix\":\"ecs\"}},\"healthCheck\":{\"command\":[\"CMD-SHELL\",\"wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1\"],\"interval\":30,\"timeout\":5,\"retries\":3,\"startPeriod\":60}}],\"networkMode\":\"awsvpc\",\"requiresCompatibilities\":[\"FARGATE\"],\"cpu\":\"256\",\"memory\":\"512\"}" \
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
    
    # Get service discovery namespace
    NAMESPACE=$(aws servicediscovery list-namespaces \
        --query "Namespaces[?Name=='${PROJECT_NAME}.local'].Id" \
        --output text 2>/dev/null | head -1 || echo "")
    
    # Get governance function name (default to project_name-governance if not set)
    GOVERNANCE_FUNCTION_NAME=${GOVERNANCE_FUNCTION_NAME:-${PROJECT_NAME}-governance}

    # Build environment variables
    ENV_VARS="[{\"name\":\"AWS_REGION\",\"value\":\"${AWS_REGION}\"},{\"name\":\"PORT\",\"value\":\"8080\"},{\"name\":\"AXON_SERVICE_URL\",\"value\":\"http://axon.${PROJECT_NAME}.local/reason\"},{\"name\":\"GOVERNANCE_FUNCTION_NAME\",\"value\":\"${GOVERNANCE_FUNCTION_NAME}\"}"
    if [ -n "$SECRET_ARN" ] && [ "$SECRET_ARN" != "None" ]; then
        ENV_VARS="${ENV_VARS},{\"name\":\"ORBIT_SECRET_ARN\",\"value\":\"${SECRET_ARN}\"}"
    fi
    ENV_VARS="${ENV_VARS}]"
    
    # Build secrets array (only if secret exists)
    if [ -n "$SECRET_ARN" ] && [ "$SECRET_ARN" != "None" ]; then
        SECRETS_JSON=",\"secrets\":[{\"name\":\"DATABASE_URL\",\"valueFrom\":\"${SECRET_ARN}:database_url::\"},{\"name\":\"API_KEY\",\"valueFrom\":\"${SECRET_ARN}:api_key::\"}]"
    else
        echo "WARNING: Secret ${PROJECT_NAME}/orbit not found. Continuing without secrets..."
        SECRETS_JSON=""
    fi
    
    # Register new task definition with latest image
    ORBIT_TASK_DEF=$(aws ecs register-task-definition \
        --family ${PROJECT_NAME}-orbit \
        --execution-role-arn "$EXECUTION_ROLE_ARN" \
        --task-role-arn "$TASK_ROLE_ARN" \
        --cli-input-json "{\"containerDefinitions\":[{\"name\":\"orbit\",\"image\":\"${IMAGE_URI}:latest\",\"essential\":true,\"portMappings\":[{\"containerPort\":8080,\"protocol\":\"tcp\"}],\"environment\":${ENV_VARS}${SECRETS_JSON},\"logConfiguration\":{\"logDriver\":\"awslogs\",\"options\":{\"awslogs-group\":\"/ecs/${PROJECT_NAME}-orbit\",\"awslogs-region\":\"${AWS_REGION}\",\"awslogs-stream-prefix\":\"ecs\"}},\"healthCheck\":{\"command\":[\"CMD-SHELL\",\"wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1\"],\"interval\":30,\"timeout\":5,\"retries\":3,\"startPeriod\":60}}],\"networkMode\":\"awsvpc\",\"requiresCompatibilities\":[\"FARGATE\"],\"cpu\":\"256\",\"memory\":\"512\"}" \
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
    echo "Waiting for services: $SERVICES"
    
    # Custom wait loop with better diagnostics (max 10 minutes = 40 attempts * 15s)
    MAX_ATTEMPTS=40
    ATTEMPT=0
    STABLE=false
    
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ] && [ "$STABLE" != "true" ]; do
        STABLE=true
        
        for SERVICE in $SERVICES; do
            SERVICE_STATUS=$(aws ecs describe-services \
                --cluster $CLUSTER_NAME \
                --services $SERVICE \
                --query 'services[0]' \
                --output json 2>/dev/null || echo "{}")
            
            # Handle jq errors gracefully
            RUNNING=$(echo "$SERVICE_STATUS" | jq -r '.runningCount // 0' 2>/dev/null || echo "0")
            DESIRED=$(echo "$SERVICE_STATUS" | jq -r '.desiredCount // 0' 2>/dev/null || echo "0")
            PENDING=$(echo "$SERVICE_STATUS" | jq -r '.pendingCount // 0' 2>/dev/null || echo "0")
            
            # Check deployment status
            DEPLOYMENT_COUNT=$(echo "$SERVICE_STATUS" | jq -r '.deployments | length' 2>/dev/null || echo "0")
            PRIMARY_DEPLOYMENT=$(echo "$SERVICE_STATUS" | jq -r '.deployments[0] // {}' 2>/dev/null || echo "{}")
            DEPLOYMENT_STATUS=$(echo "$PRIMARY_DEPLOYMENT" | jq -r '.status // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")
            DEPLOYMENT_ROLLOUT_STATE=$(echo "$PRIMARY_DEPLOYMENT" | jq -r '.rolloutState // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")
            DEPLOYMENT_RUNNING=$(echo "$PRIMARY_DEPLOYMENT" | jq -r '.runningCount // 0' 2>/dev/null || echo "0")
            DEPLOYMENT_DESIRED=$(echo "$PRIMARY_DEPLOYMENT" | jq -r '.desiredCount // 0' 2>/dev/null || echo "0")
            
            echo "  $SERVICE: Running=$RUNNING/$DESIRED, Pending=$PENDING, Deployment=$DEPLOYMENT_STATUS (rollout=$DEPLOYMENT_ROLLOUT_STATE, $DEPLOYMENT_RUNNING/$DEPLOYMENT_DESIRED)"
            
            # Service is stable if ALL of these are true:
            # 1. Running count matches desired count
            # 2. No pending tasks
            # 3. Deployment running count matches desired count
            # 4. Only one deployment (no active rollback or update in progress)
            # 5. Primary deployment rollout is COMPLETED
            SERVICE_STABLE=true
            
            if [ "$RUNNING" != "$DESIRED" ]; then
                SERVICE_STABLE=false
            fi
            
            if [ "$PENDING" != "0" ]; then
                SERVICE_STABLE=false
            fi
            
            if [ "$DEPLOYMENT_RUNNING" != "$DEPLOYMENT_DESIRED" ]; then
                SERVICE_STABLE=false
            fi
            
            if [ "$DEPLOYMENT_COUNT" != "1" ]; then
                SERVICE_STABLE=false
            fi
            
            # rolloutState must be COMPLETED for service to be stable
            if [ "$DEPLOYMENT_ROLLOUT_STATE" != "COMPLETED" ]; then
                SERVICE_STABLE=false
            fi
            
            if [ "$SERVICE_STABLE" != "true" ]; then
                STABLE=false
            fi
            
            # Check for recent task failures (last 5 minutes)
            if [ $((ATTEMPT % 4)) -eq 0 ]; then  # Every 4 attempts (1 minute)
                RECENT_STOPPED=$(aws ecs list-tasks \
                    --cluster $CLUSTER_NAME \
                    --service-name $SERVICE \
                    --desired-status STOPPED \
                    --max-items 5 \
                    --query 'taskArns[*]' \
                    --output text 2>/dev/null || echo "")
                
                if [ -n "$RECENT_STOPPED" ]; then
                    echo "  ⚠️  Found stopped tasks for $SERVICE:"
                    for TASK_ARN in $RECENT_STOPPED; do
                        TASK_INFO=$(aws ecs describe-tasks \
                            --cluster $CLUSTER_NAME \
                            --tasks $TASK_ARN \
                            --query 'tasks[0].[stoppedReason,stopCode,containers[0].exitCode]' \
                            --output text 2>/dev/null || echo "")
                        if [ -n "$TASK_INFO" ]; then
                            echo "    - Reason: $(echo $TASK_INFO | awk '{print $1}')"
                            echo "      Code: $(echo $TASK_INFO | awk '{print $2}')"
                            echo "      Exit: $(echo $TASK_INFO | awk '{print $3}')"
                        fi
                    done
                fi
            fi
        done
        
        if [ "$STABLE" = "true" ]; then
            echo "✅ All services stabilized successfully"
            break
        fi
        
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
            if [ $((ATTEMPT % 4)) -eq 0 ]; then
                echo "  ⏳ Still waiting... ($((ATTEMPT * 15 / 60)) minutes elapsed, max 10 minutes)"
            fi
            sleep 15
        fi
    done
    
    # Final status check
    if [ "$STABLE" != "true" ]; then
        echo "⚠️  Services did not fully stabilize within timeout period (10 minutes)"
        echo "Final service status:"
        for SERVICE in $SERVICES; do
            echo ""
            echo "=== $SERVICE ===" 
            aws ecs describe-services \
                --cluster $CLUSTER_NAME \
                --services $SERVICE \
                --query 'services[0].[runningCount,desiredCount,pendingCount,deployments[*].[status,runningCount,desiredCount]]' \
                --output table 2>/dev/null || true
            
            # Show recent events
            echo "Recent events:"
            aws ecs describe-services \
        --cluster $CLUSTER_NAME \
                --services $SERVICE \
                --query 'services[0].events[:5].[createdAt,message]' \
                --output table 2>/dev/null || true
        done
        
        # Don't fail - let health checks decide
        echo ""
        echo "⚠️  Continuing deployment - health checks will verify service status..."
    fi
fi

echo "Deployment completed successfully"

