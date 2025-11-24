#!/bin/bash

set -e

PROJECT_NAME=${PROJECT_NAME:-agent-runtime}
AWS_REGION=${AWS_REGION:-us-east-1}

echo "Running security scans..."

# Get ECR registry
ECR_REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.${AWS_REGION}.amazonaws.com

# Trivy scan for Docker images
if command -v trivy &> /dev/null; then
    echo "Scanning Docker images with Trivy..."
    
    if docker images | grep -q "${PROJECT_NAME}/axon"; then
        trivy image --exit-code 0 --severity HIGH,CRITICAL \
            --format table \
            ${ECR_REGISTRY}/${PROJECT_NAME}/axon:latest || echo "⚠️  Vulnerabilities found in Axon image"
    fi
    
    if docker images | grep -q "${PROJECT_NAME}/orbit"; then
        trivy image --exit-code 0 --severity HIGH,CRITICAL \
            --format table \
            ${ECR_REGISTRY}/${PROJECT_NAME}/orbit:latest || echo "⚠️  Vulnerabilities found in Orbit image"
    fi
else
    echo "⚠️  Trivy not installed. Skipping image scans."
fi

# Checkov scan for Terraform
if command -v checkov &> /dev/null; then
    echo "Scanning Terraform with Checkov..."
    if [ -d "infra" ]; then
        checkov -d infra/ --framework terraform \
            --output cli \
            --compact || echo "⚠️  Checkov found issues"
    fi
else
    echo "⚠️  Checkov not installed. Skipping Terraform scans."
fi

# Secret scanning (basic check)
echo "Scanning for potential secrets..."
if command -v gitleaks &> /dev/null; then
    gitleaks detect --verbose --redact || echo "⚠️  Potential secrets found"
else
    echo "⚠️  Gitleaks not installed. Skipping secret scans."
    # Basic grep check for common patterns
    if grep -r "AKIA[0-9A-Z]{16}" . --exclude-dir=.git --exclude-dir=node_modules 2>/dev/null; then
        echo "⚠️  Potential AWS access keys found"
    fi
fi

echo "Security scans completed"

