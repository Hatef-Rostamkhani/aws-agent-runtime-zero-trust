#!/bin/bash

set -e

SERVICE=${1:-all}
PROJECT_NAME=${PROJECT_NAME:-agent-runtime}
AWS_REGION=${AWS_REGION:-us-east-1}

echo "Building $SERVICE for $PROJECT_NAME..."

# Get ECR registry
ECR_REGISTRY=$(aws ecr describe-registry \
    --query 'registryId' \
    --output text 2>/dev/null || \
    aws sts get-caller-identity --query Account --output text).dkr.ecr.${AWS_REGION}.amazonaws.com

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $ECR_REGISTRY

if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "axon" ]; then
    echo "Building Axon..."
    cd services/axon
    docker build -t ${ECR_REGISTRY}/${PROJECT_NAME}/axon:latest .
    docker push ${ECR_REGISTRY}/${PROJECT_NAME}/axon:latest
    cd ../..
fi

if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "orbit" ]; then
    echo "Building Orbit..."
    cd services/orbit
    docker build -t ${ECR_REGISTRY}/${PROJECT_NAME}/orbit:latest .
    docker push ${ECR_REGISTRY}/${PROJECT_NAME}/orbit:latest
    cd ../..
fi

if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "governance" ]; then
    echo "Packaging Governance Lambda..."
    cd governance/lambda
    zip -r lambda.zip . -x "*.pyc" "__pycache__/*" "tests/*" "*.md" ".gitignore"
    cd ../..
fi

echo "Build completed successfully"

