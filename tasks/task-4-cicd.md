# Task 4: CI/CD Pipeline

**Duration:** 6-8 hours
**Priority:** High
**Dependencies:** Tasks 2, 3 (Microservices, Governance)

## Overview

Implement a complete CI/CD pipeline using GitHub Actions that builds, tests, scans, and deploys the microservices with blue-green deployment strategy.

## Objectives

- [ ] GitHub Actions workflow for build pipeline
- [ ] Security scanning with Trivy and vulnerability checks
- [ ] Automated testing (unit, integration)
- [ ] Blue-green deployment to ECS
- [ ] Deployment approval gates
- [ ] Automated rollback on failure
- [ ] OIDC authentication with AWS
- [ ] Branch protection rules
- [ ] Deployment notifications

## Prerequisites

- [ ] GitHub repository created
- [ ] Tasks 2 and 3 completed
- [ ] Docker images built and pushed to ECR
- [ ] AWS OIDC provider configured
- [ ] GitHub Actions secrets configured

## File Structure

```
.github/
├── workflows/
│   ├── build.yml          # Build and test pipeline
│   ├── security.yml       # Security scanning
│   ├── deploy.yml         # Deployment pipeline
│   └── shared/
│       ├── build-action.yml
│       └── deploy-action.yml
cicd/
├── scripts/
│   ├── build.sh
│   ├── test.sh
│   ├── deploy.sh
│   ├── rollback.sh
│   └── notify.sh
└── docker/
    ├── Dockerfile.base
    └── docker-bake.hcl
```

## Implementation Steps

### Step 4.1: Build Pipeline (2-3 hours)

**File: .github/workflows/build.yml**

```yaml
name: Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ${{ secrets.AWS_ECR_REGISTRY }}
  AWS_REGION: ${{ secrets.AWS_REGION }}

jobs:
  build-axon:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_GITHUB_ACTIONS_ROLE }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v2

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ secrets.PROJECT_NAME }}/axon
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
          type=raw,value=latest,enable={{is_default_branch}}

    - name: Build and push Axon
      uses: docker/build-push-action@v5
      with:
        context: ./services/axon
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
        platforms: linux/amd64

    - name: Run Axon tests
      run: |
        cd services/axon
        docker run --rm ${{ env.REGISTRY }}/${{ secrets.PROJECT_NAME }}/axon:${{ github.sha }} go test ./tests/... -v

  build-orbit:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_GITHUB_ACTIONS_ROLE }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v2

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ secrets.PROJECT_NAME }}/orbit
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
          type=raw,value=latest,enable={{is_default_branch}}

    - name: Build and push Orbit
      uses: docker/build-push-action@v5
      with:
        context: ./services/orbit
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
        platforms: linux/amd64

    - name: Run Orbit tests
      run: |
        cd services/orbit
        docker run --rm ${{ env.REGISTRY }}/${{ secrets.PROJECT_NAME }}/orbit:${{ github.sha }} go test ./tests/... -v

  build-governance:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_GITHUB_ACTIONS_ROLE }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Setup Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'

    - name: Install dependencies and test
      run: |
        cd governance/lambda
        pip install -r requirements.txt
        python -m pytest tests/unit/ -v

    - name: Package Lambda
      run: |
        cd governance/lambda
        zip -r lambda.zip .

    - name: Upload Lambda package
      uses: actions/upload-artifact@v4
      with:
        name: governance-lambda
        path: governance/lambda/lambda.zip
```

**Test Step 4.1:**

```bash
# Test GitHub Actions locally (using act or similar)
# Or manually test the build steps

# Test Docker build locally
cd services/axon
docker build -t axon-test .
docker run axon-test go test ./tests/... -v
```

### Step 4.2: Security Scanning (1-2 hours)

**File: .github/workflows/security.yml**

```yaml
name: Security Scan

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  schedule:
    # Run daily at 2 AM UTC
    - cron: '0 2 * * *'

env:
  REGISTRY: ${{ secrets.AWS_ECR_REGISTRY }}
  AWS_REGION: ${{ secrets.AWS_REGION }}

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
      security-events: write

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_GITHUB_ACTIONS_ROLE }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Login to Amazon ECR
      uses: aws-actions/amazon-ecr-login@v2

    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'image'
        scan-ref: '${{ env.REGISTRY }}/${{ secrets.PROJECT_NAME }}/axon:latest,${{ env.REGISTRY }}/${{ secrets.PROJECT_NAME }}/orbit:latest'
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH'

    - name: Upload Trivy scan results to GitHub Security tab
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'

    - name: Fail on critical vulnerabilities
      if: steps.trivy.outputs.exit-code == 1
      run: |
        echo "Critical or high severity vulnerabilities found"
        exit 1

  codeql-scan:
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write

    steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Initialize CodeQL
      uses: github/codeql-action/init@v2
      with:
        languages: go,python,terraform

    - name: Autobuild
      uses: github/codeql-action/autobuild@v2

    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v2

  checkov-scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Run Checkov
      uses: bridgecrewio/checkov-action@v12
      with:
        directory: infra/
        framework: terraform
        output_format: cli
        output_file_path: checkov-results.txt

    - name: Upload Checkov results
      uses: actions/upload-artifact@v4
      with:
        name: checkov-results
        path: checkov-results.txt
```

**File: cicd/scripts/scan.sh**

```bash
#!/bin/bash

set -e

echo "Running security scans..."

# Trivy scan for Docker images
echo "Scanning Docker images with Trivy..."
trivy image --exit-code 1 --severity HIGH,CRITICAL \
  --format table \
  ${AWS_ECR_REGISTRY}/${PROJECT_NAME}/axon:latest \
  ${AWS_ECR_REGISTRY}/${PROJECT_NAME}/orbit:latest

# Checkov scan for Terraform
echo "Scanning Terraform with Checkov..."
checkov -d infra/ --framework terraform \
  --output cli \
  --compact

# Secret scanning
echo "Scanning for secrets..."
gitleaks detect --verbose --redact

echo "Security scans completed successfully"
```

**Test Step 4.2:**

```bash
# Test Trivy scan
trivy image --exit-code 1 --severity HIGH,CRITICAL \
  ${AWS_ECR_REGISTRY}/${PROJECT_NAME}/axon:latest

# Test Checkov scan
checkov -d infra/ --framework terraform --output cli
```

### Step 4.3: Testing Pipeline (1-2 hours)

**File: .github/workflows/test.yml**

```yaml
name: Testing

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ${{ secrets.AWS_ECR_REGISTRY }}
  AWS_REGION: ${{ secrets.AWS_REGION }}

jobs:
  unit-tests:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Go
      uses: actions/setup-go@v4
      with:
        go-version: '1.21'

    - name: Setup Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'

    - name: Run Axon unit tests
      run: |
        cd services/axon
        go mod tidy
        go test ./tests/unit/... -v -coverprofile=coverage.out
        go tool cover -html=coverage.out -o coverage.html

    - name: Run Orbit unit tests
      run: |
        cd services/orbit
        go mod tidy
        go test ./tests/unit/... -v -coverprofile=coverage.out
        go tool cover -html=coverage.out -o coverage.html

    - name: Run Governance unit tests
      run: |
        cd governance/lambda
        pip install -r requirements.txt
        python -m pytest tests/unit/ -v --cov=handler --cov-report=html

    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      with:
        files: ./services/axon/coverage.out,./services/orbit/coverage.out
        flags: unittests
        name: codecov-umbrella

  integration-tests:
    runs-on: ubuntu-latest
    needs: [unit-tests]
    if: github.ref == 'refs/heads/main'

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_GITHUB_ACTIONS_ROLE }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Setup test environment
      run: |
        # Create test stack
        aws cloudformation create-stack \
          --stack-name ${PROJECT_NAME}-test \
          --template-body file://infra/test-stack.yaml \
          --parameters ParameterKey=ProjectName,ParameterValue=${PROJECT_NAME}

    - name: Run integration tests
      run: |
        cd cicd/scripts
        ./run-integration-tests.sh

    - name: Cleanup test environment
      if: always()
      run: |
        aws cloudformation delete-stack --stack-name ${PROJECT_NAME}-test
```

**File: cicd/scripts/test.sh**

```bash
#!/bin/bash

set -e

echo "Running comprehensive tests..."

# Unit tests
echo "Running unit tests..."
cd services/axon && go test ./tests/unit/... -v -race -cover
cd ../orbit && go test ./tests/unit/... -v -race -cover
cd ../../governance/lambda && python -m pytest tests/unit/ -v

# Integration tests (if infrastructure available)
if [ "$RUN_INTEGRATION" = "true" ]; then
    echo "Running integration tests..."
    ./run-integration-tests.sh
fi

# Load tests (basic)
echo "Running load tests..."
cd services/axon
docker run --rm -p 8080:80 axon-test &
sleep 5
hey -n 1000 -c 10 http://localhost:8080/health
kill %1

echo "All tests completed successfully"
```

**Test Step 4.3:**

```bash
# Run unit tests locally
cd services/axon && go test ./tests/unit/... -v
cd ../orbit && go test ./tests/unit/... -v
cd ../../governance/lambda && python -m pytest tests/unit/ -v
```

### Step 4.4: Deployment Pipeline (2-3 hours)

Implement two separate pipelines: one for application deployment (automatic) and one for infrastructure deployment (manual).

#### Application Deployment Pipeline (Automatic)

**File: .github/workflows/deploy-app.yml**

```yaml
name: Deploy Application

on:
  push:
    branches: [ main ]
    paths:
      - 'services/**'
      - 'governance/**'
      - '.github/workflows/**'
      - 'cicd/**'
      # Exclude infrastructure changes

jobs:
  deploy-app:
    runs-on: ubuntu-latest
    environment: production

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE }}
        aws-region: ${{ secrets.AWS_REGION }}

    - name: Download Lambda package
      uses: actions/download-artifact@v4
      with:
        name: governance-lambda

    - name: Deploy Governance Lambda
      run: |
        cd governance/terraform
        terraform init
        terraform apply -auto-approve

    - name: Blue-Green Deployment
      run: |
        cd cicd/scripts
        ./deploy-blue-green.sh

    - name: Run smoke tests
      run: |
        cd cicd/scripts
        ./smoke-tests.sh

    - name: Notify success
      if: success()
      run: |
        cd cicd/scripts
        ./notify.sh "success" "application"

    - name: Rollback on failure
      if: failure()
      run: |
        cd cicd/scripts
        ./rollback.sh
        ./notify.sh "failure" "application"
```

#### Infrastructure Deployment Pipeline (Manual)

**File: .github/workflows/deploy-infra.yml**

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [ main ]
    paths:
      - 'infra/**'
    tags:
      - 'infra-v*'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        default: 'staging'
        type: choice
        options:
        - staging
        - production

env:
  AWS_REGION: ${{ secrets.AWS_REGION }}
  ENVIRONMENT: ${{ github.event.inputs.environment || 'production' }}

jobs:
  deploy-infrastructure:
    runs-on: ubuntu-latest
    environment: ${{ env.ENVIRONMENT }}

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_INFRA_DEPLOY_ROLE }}
        aws-region: ${{ env.AWS_REGION }}

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3

    - name: Terraform Init
      run: |
        cd infra
        terraform init

    - name: Terraform Plan
      run: |
        cd infra
        terraform plan -out=tfplan -var="environment=${{ env.ENVIRONMENT }}"

    - name: Terraform Apply
      run: |
        cd infra
        terraform apply tfplan

    - name: Notify success
      if: success()
      run: |
        echo "Infrastructure deployed to ${{ env.ENVIRONMENT }}"

    - name: Notify failure
      if: failure()
      run: |
        echo "Infrastructure deployment failed for ${{ env.ENVIRONMENT }}"
```

**File: cicd/scripts/deploy.sh**

```bash
#!/bin/bash

set -e

ENVIRONMENT=${1:-staging}
SERVICE_NAME=${2:-all}

echo "Deploying to $ENVIRONMENT..."

# Update ECS task definitions
if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "axon" ]; then
    echo "Updating Axon task definition..."
    AXON_TASK_DEF=$(aws ecs register-task-definition \
        --cli-input-json file://infra/modules/ecs/task-definitions/axon.json \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)

    aws ecs update-service \
        --cluster ${PROJECT_NAME}-cluster \
        --service ${PROJECT_NAME}-axon \
        --task-definition $AXON_TASK_DEF
fi

if [ "$SERVICE_NAME" = "all" ] || [ "$SERVICE_NAME" = "orbit" ]; then
    echo "Updating Orbit task definition..."
    ORBIT_TASK_DEF=$(aws ecs register-task-definition \
        --cli-input-json file://infra/modules/ecs/task-definitions/orbit.json \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)

    aws ecs update-service \
        --cluster ${PROJECT_NAME}-cluster \
        --service ${PROJECT_NAME}-orbit \
        --task-definition $ORBIT_TASK_DEF
fi

echo "Waiting for services to stabilize..."
aws ecs wait services-stable \
    --cluster ${PROJECT_NAME}-cluster \
    --services ${PROJECT_NAME}-axon ${PROJECT_NAME}-orbit

echo "Deployment completed successfully"
```

**File: cicd/scripts/deploy-blue-green.sh**

```bash
#!/bin/bash

set -e

echo "Starting blue-green deployment..."

# Get current service state
CURRENT_AXON_TASK=$(aws ecs describe-services \
    --cluster ${PROJECT_NAME}-cluster \
    --services ${PROJECT_NAME}-axon \
    --query 'services[0].taskDefinition' \
    --output text)

CURRENT_ORBIT_TASK=$(aws ecs describe-services \
    --cluster ${PROJECT_NAME}-cluster \
    --services ${PROJECT_NAME}-orbit \
    --query 'services[0].taskDefinition' \
    --output text)

# Deploy new version (green)
echo "Deploying green version..."
./deploy.sh production axon
./deploy.sh production orbit

# Run health checks
echo "Running health checks..."
if ./health-check.sh; then
    echo "Health checks passed. Switching to green version..."
    # Green is now live, blue becomes standby

    # Optional: Scale down blue version after successful deployment
    echo "Scaling down blue version..."
    aws ecs update-service \
        --cluster ${PROJECT_NAME}-cluster \
        --service ${PROJECT_NAME}-axon-blue \
        --desired-count 0

    aws ecs update-service \
        --cluster ${PROJECT_NAME}-cluster \
        --service ${PROJECT_NAME}-orbit-blue \
        --desired-count 0

else
    echo "Health checks failed. Rolling back..."
    ./rollback.sh
    exit 1
fi

echo "Blue-green deployment completed successfully"
```

**File: cicd/scripts/rollback.sh**

```bash
#!/bin/bash

set -e

echo "Starting rollback..."

# Get previous task definitions from tags or parameter store
PREVIOUS_AXON_TASK=$(aws ssm get-parameter \
    --name "/${PROJECT_NAME}/axon/previous-task-def" \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || echo "")

PREVIOUS_ORBIT_TASK=$(aws ssm get-parameter \
    --name "/${PROJECT_NAME}/orbit/previous-task-def" \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || echo "")

if [ -n "$PREVIOUS_AXON_TASK" ]; then
    echo "Rolling back Axon to $PREVIOUS_AXON_TASK"
    aws ecs update-service \
        --cluster ${PROJECT_NAME}-cluster \
        --service ${PROJECT_NAME}-axon \
        --task-definition $PREVIOUS_AXON_TASK
fi

if [ -n "$PREVIOUS_ORBIT_TASK" ]; then
    echo "Rolling back Orbit to $PREVIOUS_ORBIT_TASK"
    aws ecs update-service \
        --cluster ${PROJECT_NAME}-cluster \
        --service ${PROJECT_NAME}-orbit \
        --task-definition $PREVIOUS_ORBIT_TASK
fi

# Wait for services to stabilize
aws ecs wait services-stable \
    --cluster ${PROJECT_NAME}-cluster \
    --services ${PROJECT_NAME}-axon ${PROJECT_NAME}-orbit

echo "Rollback completed"
```

**Test Step 4.4:**

```bash
# Test deployment script (dry run)
cd cicd/scripts
./deploy.sh --dry-run

# Test health checks
./health-check.sh
```

### Step 4.5: Pipeline Infrastructure (1 hour)

Setup OIDC authentication with separate IAM roles for application and infrastructure deployments.

#### OIDC Provider and IAM Roles

**File: infra/modules/cicd/github-oidc.tf**

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
  ]

  tags = {
    Name = "${var.project_name}-github-oidc"
  }
}

# IAM Role for Application Deployments (less privileged)
resource "aws_iam_role" "github_actions_app" {
  name = "${var.project_name}-github-actions-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-github-actions-app-role"
  }
}

resource "aws_iam_role_policy" "github_actions_app" {
  name = "${var.project_name}-github-actions-app-policy"
  role = aws_iam_role.github_actions_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTasks",
          "ecs:DescribeTasks"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.governance.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.axon.arn,
          aws_secretsmanager_secret.orbit.arn
        ]
      }
    ]
  })
}

# IAM Role for Infrastructure Deployments (more privileged)
resource "aws_iam_role" "github_actions_infra" {
  name = "${var.project_name}-github-actions-infra-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-github-actions-infra-role"
  }
}

resource "aws_iam_role_policy" "github_actions_infra" {
  name = "${var.project_name}-github-actions-infra-policy"
  role = aws_iam_role.github_actions_infra.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "ecs:*",
          "rds:*",
          "lambda:*",
          "iam:*",
          "kms:*",
          "secretsmanager:*",
          "cloudwatch:*",
          "logs:*",
          "apigateway:*",
          "elasticloadbalancing:*",
          "route53:*",
          "s3:*",
          "dynamodb:*",
          "appmesh:*"
        ]
        Resource = "*"
      }
    ]
  })
}
```

**File: .github/workflows/shared/deploy-action.yml**

```yaml
name: Deploy Action

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      service:
        required: true
        type: string

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}

    steps:
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE }}
        aws-region: ${{ secrets.AWS_REGION }}

    - name: Deploy service
      run: |
        cd cicd/scripts
        ./deploy.sh ${{ inputs.environment }} ${{ inputs.service }}

    - name: Health check
      run: |
        cd cicd/scripts
        ./health-check.sh ${{ inputs.service }}
```

**Test Step 4.5:**

```bash
# Test OIDC setup
aws iam get-open-id-connect-provider --open-id-connect-provider-arn $OIDC_ARN

# Test GitHub Actions role
aws sts assume-role --role-arn $GITHUB_ROLE_ARN --role-session-name test
```

## Acceptance Criteria

- [ ] Two separate GitHub Actions workflows created (deploy-app.yml and deploy-infra.yml)
- [ ] Application pipeline triggers automatically on push to main (services/governance changes)
- [ ] Infrastructure pipeline requires manual trigger or tag (infra/ changes)
- [ ] Docker images build and push to ECR successfully
- [ ] Security scanning passes without critical vulnerabilities
- [ ] Unit and integration tests run in CI and pass
- [ ] Blue-green deployment works correctly for application updates
- [ ] Terraform deployment works for infrastructure changes
- [ ] Separate IAM roles for application and infrastructure deployments
- [ ] Application role has limited permissions (ECS, ECR, Lambda, Secrets)
- [ ] Infrastructure role has broader permissions (all AWS services)
- [ ] Rollback procedures functional for both pipelines
- [ ] OIDC authentication configured for both roles
- [ ] Branch protection rules applied
- [ ] Deployment notifications sent
- [ ] Both pipelines complete end-to-end successfully

## Rollback Procedure

If CI/CD deployment fails:

```bash
# Manual rollback
cd cicd/scripts
./rollback.sh

# Or revert GitHub Actions deployment
# Delete failed deployment from GitHub
# Revert commit that triggered failed deployment
```

## Testing Script

Create `tasks/test-task-4.sh`:

```bash
#!/bin/bash
set -e

echo "Testing Task 4: CI/CD Pipeline"

# Check GitHub Actions workflows exist
if [ ! -f ".github/workflows/build.yml" ]; then
    echo "❌ Build workflow not found"
    exit 1
fi
echo "✅ Build workflow exists"

if [ ! -f ".github/workflows/deploy.yml" ]; then
    echo "❌ Deploy workflow not found"
    exit 1
fi
echo "✅ Deploy workflow exists"

# Test Docker builds
echo "Testing Docker builds..."
cd services/axon
docker build -t axon-test .
echo "✅ Axon Docker build successful"

cd ../orbit
docker build -t orbit-test .
echo "✅ Orbit Docker build successful"

# Test deployment scripts (syntax check)
cd ../../cicd/scripts
bash -n deploy.sh
bash -n rollback.sh
echo "✅ Deployment scripts syntax OK"

# Test OIDC configuration
OIDC_EXISTS=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[?contains(Arn, `github`)] | length(@)')
if [ "$OIDC_EXISTS" -eq 0 ]; then
    echo "❌ GitHub OIDC provider not configured"
    exit 1
fi
echo "✅ GitHub OIDC configured"

# Test ECR repositories
AXON_REPO=$(aws ecr describe-repositories --repository-names ${PROJECT_NAME}/axon --query 'repositories[0].repositoryName' 2>/dev/null || echo "")
if [ "$AXON_REPO" != "${PROJECT_NAME}/axon" ]; then
    echo "❌ Axon ECR repository not found"
    exit 1
fi
echo "✅ ECR repositories exist"

echo ""
echo "🎉 Task 4 CI/CD Pipeline: PASSED"
```
