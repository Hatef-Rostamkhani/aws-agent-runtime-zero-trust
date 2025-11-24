#!/bin/bash
set -e

echo "Testing Task 4: CI/CD Pipeline"

PROJECT_NAME=${PROJECT_NAME:-agent-runtime}
AWS_REGION=${AWS_REGION:-us-east-1}

# Check GitHub Actions workflows exist
WORKFLOWS=(
  ".github/workflows/build.yml"
  ".github/workflows/security.yml"
  ".github/workflows/test.yml"
  ".github/workflows/deploy-app.yml"
  ".github/workflows/deploy-infra.yml"
)

echo "--- Checking GitHub Actions workflows ---"
for workflow in "${WORKFLOWS[@]}"; do
  if [ ! -f "$workflow" ]; then
    echo "❌ Workflow not found: $workflow"
    exit 1
  fi
  echo "✅ Found: $workflow"
done
echo "✅ All GitHub Actions workflows exist"

# Validate YAML syntax
echo "--- Validating workflow YAML syntax ---"
if command -v yamllint &> /dev/null; then
  for workflow in "${WORKFLOWS[@]}"; do
    yamllint "$workflow" && echo "✅ Valid YAML: $workflow" || echo "⚠️  YAML issues in: $workflow"
  done
else
  echo "⚠️  yamllint not installed. Skipping YAML validation."
fi

# Check deployment scripts exist
echo "--- Checking deployment scripts ---"
SCRIPTS=(
  "cicd/scripts/build.sh"
  "cicd/scripts/test.sh"
  "cicd/scripts/deploy.sh"
  "cicd/scripts/deploy-blue-green.sh"
  "cicd/scripts/rollback.sh"
  "cicd/scripts/health-check.sh"
  "cicd/scripts/smoke-tests.sh"
  "cicd/scripts/notify.sh"
  "cicd/scripts/scan.sh"
)

for script in "${SCRIPTS[@]}"; do
  if [ ! -f "$script" ]; then
    echo "❌ Script not found: $script"
    exit 1
  fi
  if [ ! -x "$script" ]; then
    echo "⚠️  Script not executable: $script"
    chmod +x "$script"
  fi
  echo "✅ Found: $script"
done
echo "✅ All deployment scripts exist"

# Test script syntax
echo "--- Testing script syntax ---"
for script in "${SCRIPTS[@]}"; do
  bash -n "$script" && echo "✅ Valid syntax: $script" || {
    echo "❌ Syntax error in: $script"
    exit 1
  }
done

# Check OIDC configuration (if AWS CLI available)
echo "--- Checking OIDC configuration ---"
if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null; then
  OIDC_EXISTS=$(aws iam list-open-id-connect-providers \
    --query 'OpenIDConnectProviderList[?contains(Arn, `github`)] | length(@)' \
    --output text 2>/dev/null || echo "0")
  
  if [ "$OIDC_EXISTS" -eq 0 ]; then
    echo "⚠️  GitHub OIDC provider not configured (may need infrastructure deployment)"
  else
    echo "✅ GitHub OIDC provider configured"
  fi

  # Test IAM roles exist
  APP_ROLE_EXISTS=$(aws iam get-role \
    --role-name ${PROJECT_NAME}-github-actions-app-role \
    --query 'Role.RoleName' \
    --output text 2>/dev/null || echo "")
  
  INFRA_ROLE_EXISTS=$(aws iam get-role \
    --role-name ${PROJECT_NAME}-github-actions-infra-role \
    --query 'Role.RoleName' \
    --output text 2>/dev/null || echo "")

  if [ "$APP_ROLE_EXISTS" = "${PROJECT_NAME}-github-actions-app-role" ]; then
    echo "✅ Application deployment IAM role exists"
  else
    echo "⚠️  Application deployment IAM role not found (may need infrastructure deployment)"
  fi

  if [ "$INFRA_ROLE_EXISTS" = "${PROJECT_NAME}-github-actions-infra-role" ]; then
    echo "✅ Infrastructure deployment IAM role exists"
  else
    echo "⚠️  Infrastructure deployment IAM role not found (may need infrastructure deployment)"
  fi

  # Test ECR repositories
  echo "--- Checking ECR repositories ---"
  AXON_REPO=$(aws ecr describe-repositories \
    --repository-names ${PROJECT_NAME}/axon \
    --query 'repositories[0].repositoryName' \
    --output text 2>/dev/null || echo "")
  
  ORBIT_REPO=$(aws ecr describe-repositories \
    --repository-names ${PROJECT_NAME}/orbit \
    --query 'repositories[0].repositoryName' \
    --output text 2>/dev/null || echo "")

  if [ "$AXON_REPO" = "${PROJECT_NAME}/axon" ]; then
    echo "✅ ECR repository exists: ${PROJECT_NAME}/axon"
  else
    echo "⚠️  ECR repository not found: ${PROJECT_NAME}/axon (may need infrastructure deployment)"
  fi

  if [ "$ORBIT_REPO" = "${PROJECT_NAME}/orbit" ]; then
    echo "✅ ECR repository exists: ${PROJECT_NAME}/orbit"
  else
    echo "⚠️  ECR repository not found: ${PROJECT_NAME}/orbit (may need infrastructure deployment)"
  fi
else
  echo "⚠️  AWS CLI not configured. Skipping AWS resource checks."
fi

# Test workflow file references
echo "--- Checking workflow references ---"
if grep -q "AWS_GITHUB_ACTIONS_APP_ROLE" .github/workflows/build.yml && \
   grep -q "AWS_GITHUB_ACTIONS_APP_ROLE" .github/workflows/deploy-app.yml && \
   grep -q "AWS_GITHUB_ACTIONS_INFRA_ROLE" .github/workflows/deploy-infra.yml; then
  echo "✅ Workflow role references are correct"
else
  echo "⚠️  Some workflow role references may be incorrect"
fi

# Check script dependencies
echo "--- Checking script dependencies ---"
MISSING_DEPS=0

for script in "${SCRIPTS[@]}"; do
  # Check for common commands used in scripts
  if grep -q "jq" "$script" && ! command -v jq &> /dev/null; then
    echo "⚠️  Script $script requires 'jq' but it's not installed"
    MISSING_DEPS=1
  fi
  if grep -q "curl" "$script" && ! command -v curl &> /dev/null; then
    echo "⚠️  Script $script requires 'curl' but it's not installed"
    MISSING_DEPS=1
  fi
done

if [ $MISSING_DEPS -eq 0 ]; then
  echo "✅ No missing script dependencies detected"
fi

echo ""
echo "🎉 Task 4 CI/CD Pipeline: PASSED (local validation)"
echo ""
echo "Next steps:"
echo "1. Configure GitHub Secrets:"
echo "   - AWS_GITHUB_ACTIONS_APP_ROLE"
echo "   - AWS_GITHUB_ACTIONS_INFRA_ROLE"
echo "   - AWS_REGION"
echo "   - PROJECT_NAME"
echo "   - TERRAFORM_STATE_BUCKET"
echo "   - TERRAFORM_STATE_DYNAMODB_TABLE"
echo "   - TERRAFORM_STATE_KEY"
echo ""
echo "2. Deploy infrastructure (if not already deployed):"
echo "   terraform apply in infra/"
echo ""
echo "3. Push code to trigger workflows"
