#!/bin/bash
set -e

echo "Testing Task 4: CI/CD Pipeline"

PROJECT_NAME=${PROJECT_NAME:-agent-runtime}

# Check GitHub Actions workflows exist
WORKFLOWS=(
  "../.github/workflows/build.yml"
  "../.github/workflows/security.yml"
  "../.github/workflows/test.yml"
  "../.github/workflows/deploy-app.yml"
  "../.github/workflows/deploy-infra.yml"
)

for workflow in "${WORKFLOWS[@]}"; do
  if [ ! -f "$workflow" ]; then
    echo "❌ Workflow not found: $workflow"
    exit 1
  fi
done
echo "✅ All GitHub Actions workflows exist"

# Test ECR repositories
AXON_REPO=$(aws ecr describe-repositories --repository-names ${PROJECT_NAME}/axon --query 'repositories[0].repositoryName' 2>/dev/null || echo "")
ORBIT_REPO=$(aws ecr describe-repositories --repository-names ${PROJECT_NAME}/orbit --query 'repositories[0].repositoryName' 2>/dev/null || echo "")

if [ "$AXON_REPO" != "${PROJECT_NAME}/axon" ] || [ "$ORBIT_REPO" != "${PROJECT_NAME}/orbit" ]; then
    echo "❌ ECR repositories not found"
    exit 1
fi
echo "✅ ECR repositories exist"

# Test OIDC configuration
OIDC_EXISTS=$(aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[?contains(Arn, `github`)] | length(@)' 2>/dev/null || echo 0)
if [ "$OIDC_EXISTS" -eq 0 ]; then
    echo "❌ GitHub OIDC provider not configured"
    exit 1
fi
echo "✅ GitHub OIDC configured"

# Test IAM roles exist
APP_ROLE_EXISTS=$(aws iam get-role --role-name ${PROJECT_NAME}-github-actions-app-role --query 'Role.RoleName' 2>/dev/null || echo "")
INFRA_ROLE_EXISTS=$(aws iam get-role --role-name ${PROJECT_NAME}-github-actions-infra-role --query 'Role.RoleName' 2>/dev/null || echo "")

if [ "$APP_ROLE_EXISTS" != "${PROJECT_NAME}-github-actions-app-role" ]; then
    echo "❌ Application deployment IAM role not found"
    exit 1
fi
echo "✅ Application deployment IAM role exists"

if [ "$INFRA_ROLE_EXISTS" != "${PROJECT_NAME}-github-actions-infra-role" ]; then
    echo "❌ Infrastructure deployment IAM role not found"
    exit 1
fi
echo "✅ Infrastructure deployment IAM role exists"

# Test deployment scripts exist and are executable
SCRIPTS=(
  "../cicd/scripts/deploy.sh"
  "../cicd/scripts/deploy-blue-green.sh"
  "../cicd/scripts/rollback.sh"
)

for script in "${SCRIPTS[@]}"; do
  if [ ! -f "$script" ]; then
    echo "❌ Script not found: $script"
    exit 1
  fi
  if [ ! -x "$script" ]; then
    echo "⚠️  Script not executable: $script"
  fi
done
echo "✅ Deployment scripts exist"

echo ""
echo "🎉 Task 4 CI/CD Pipeline: PASSED"
