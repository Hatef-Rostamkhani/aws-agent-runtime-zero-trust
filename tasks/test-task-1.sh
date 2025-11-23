#!/bin/bash
set -e

echo "Testing Task 1: Infrastructure Setup"

# Source environment variables
if [ -f "../.env.local" ]; then
    source ../.env.local
fi

# Set defaults
PROJECT_NAME=${PROJECT_NAME:-agent-runtime}
AWS_REGION=${AWS_REGION:-us-east-1}

# Test VPC creation
VPC_COUNT=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=${PROJECT_NAME}-vpc --query 'length(Vpcs)' 2>/dev/null || echo 0)
if [ "$VPC_COUNT" -eq 0 ]; then
    echo "❌ VPC not found"
    exit 1
fi
echo "✅ VPC created"

# Test subnets
SUBNET_COUNT=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=${PROJECT_NAME}-vpc --query 'Vpcs[0].VpcId' --output text) --query 'length(Subnets)' 2>/dev/null || echo 0)
EXPECTED_SUBNETS=9  # 3 public + 3 private + 3 axon-runtime
if [ "$SUBNET_COUNT" -ne $EXPECTED_SUBNETS ]; then
    echo "❌ Expected $EXPECTED_SUBNETS subnets, found $SUBNET_COUNT"
    exit 1
fi
echo "✅ All subnets created"

# Test ECS cluster
CLUSTER_STATUS=$(aws ecs describe-clusters --clusters ${PROJECT_NAME}-cluster --query 'clusters[0].status' 2>/dev/null || echo "MISSING")
if [ "$CLUSTER_STATUS" != "\"ACTIVE\"" ]; then
    echo "❌ ECS cluster not active"
    exit 1
fi
echo "✅ ECS cluster active"

# Test ECR repositories
AXON_REPO=$(aws ecr describe-repositories --repository-names ${PROJECT_NAME}/axon --query 'repositories[0].repositoryName' 2>/dev/null || echo "")
ORBIT_REPO=$(aws ecr describe-repositories --repository-names ${PROJECT_NAME}/orbit --query 'repositories[0].repositoryName' 2>/dev/null || echo "")

if [ "$AXON_REPO" != "${PROJECT_NAME}/axon" ] || [ "$ORBIT_REPO" != "${PROJECT_NAME}/orbit" ]; then
    echo "❌ ECR repositories not found"
    exit 1
fi
echo "✅ ECR repositories created"

# Test KMS keys
AXON_KEY_EXISTS=$(aws kms describe-key --key-id alias/${PROJECT_NAME}-axon --query 'KeyMetadata.KeyState' 2>/dev/null || echo "DISABLED")
ORBIT_KEY_EXISTS=$(aws kms describe-key --key-id alias/${PROJECT_NAME}-orbit --query 'KeyMetadata.KeyState' 2>/dev/null || echo "DISABLED")

if [ "$AXON_KEY_EXISTS" != "\"Enabled\"" ] || [ "$ORBIT_KEY_EXISTS" != "\"Enabled\"" ]; then
    echo "❌ KMS keys not enabled"
    exit 1
fi
echo "✅ KMS keys configured"

# Test Secrets Manager
AXON_SECRET_EXISTS=$(aws secretsmanager describe-secret --secret-id ${PROJECT_NAME}/axon --query 'Name' 2>/dev/null || echo "")
ORBIT_SECRET_EXISTS=$(aws secretsmanager describe-secret --secret-id ${PROJECT_NAME}/orbit --query 'Name' 2>/dev/null || echo "")

if [ "$AXON_SECRET_EXISTS" != "\"${PROJECT_NAME}/axon\"" ] || [ "$ORBIT_SECRET_EXISTS" != "\"${PROJECT_NAME}/orbit\"" ]; then
    echo "❌ Secrets not created"
    exit 1
fi
echo "✅ Secrets Manager configured"

# Test IAM roles and boundaries
AXON_ROLE_EXISTS=$(aws iam get-role --role-name ${PROJECT_NAME}-axon-role --query 'Role.RoleName' 2>/dev/null || echo "")
ORBIT_ROLE_EXISTS=$(aws iam get-role --role-name ${PROJECT_NAME}-orbit-role --query 'Role.RoleName' 2>/dev/null || echo "")

if [ "$AXON_ROLE_EXISTS" != "\"${PROJECT_NAME}-axon-role\"" ] || [ "$ORBIT_ROLE_EXISTS" != "\"${PROJECT_NAME}-orbit-role\"" ]; then
    echo "❌ IAM roles not created"
    exit 1
fi
echo "✅ IAM roles configured"

# Test App Mesh
MESH_EXISTS=$(aws appmesh describe-mesh --mesh-name ${PROJECT_NAME}-mesh --query 'meshName' 2>/dev/null || echo "")
if [ "$MESH_EXISTS" != "\"${PROJECT_NAME}-mesh\"" ]; then
    echo "❌ App Mesh not created"
    exit 1
fi
echo "✅ App Mesh configured"

# Test ALB
ALB_EXISTS=$(aws elbv2 describe-load-balancers --names ${PROJECT_NAME}-alb --query 'LoadBalancers[0].LoadBalancerName' 2>/dev/null || echo "")
if [ "$ALB_EXISTS" != "\"${PROJECT_NAME}-alb\"" ]; then
    echo "❌ ALB not created"
    exit 1
fi
echo "✅ ALB configured"

echo ""
echo "🎉 Task 1 Infrastructure Setup: PASSED"
