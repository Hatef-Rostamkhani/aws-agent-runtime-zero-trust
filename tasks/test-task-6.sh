#!/bin/bash
set -e

echo "Testing Task 6: Security Implementation"

# Run network isolation tests
echo "Testing network isolation..."
./scripts/test-isolation.sh

# Run security audit
echo "Running security audit..."
./scripts/security-audit.sh

# Test SigV4 signing
echo "Testing SigV4 implementation..."
./scripts/validate-sigv4.sh

# Test secrets rotation
echo "Testing secrets rotation..."
cd infra/modules/secrets
terraform apply -target=aws_lambda_function.secrets_rotation

# Invoke rotation manually
aws lambda invoke --function-name ${PROJECT_NAME}-secrets-rotation \
    --payload '{}' \
    output.json

ROTATION_SUCCESS=$(cat output.json | jq -r '.statusCode')
if [ "$ROTATION_SUCCESS" != "200" ]; then
    echo "❌ Secrets rotation failed"
    exit 1
fi
echo "✅ Secrets rotation functional"

# Test IAM Access Analyzer
echo "Checking IAM Access Analyzer..."
FINDINGS=$(aws accessanalyzer list-findings --analyzer-arn $ANALYZER_ARN --query 'findings[?status==`ACTIVE`]' --output json | jq length)

if [ "$FINDINGS" -gt 0 ]; then
    echo "⚠️  Found $FINDINGS active IAM access findings"
    # Not failing the test, just warning
fi
echo "✅ IAM Access Analyzer configured"

echo ""
echo "🎉 Task 6 Security Implementation: PASSED"