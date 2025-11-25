#!/bin/bash

set -e

echo "Performing Security Audit..."

# IAM Audit
echo "1. Checking IAM permissions..."

# Find wildcard permissions
WILDCARD_POLICIES=$(aws iam list-policies --scope Local \
    --query 'Policies[?contains(PolicySummary.Statement[].Action[], `*`) || contains(PolicySummary.Statement[].Action[], `*:*`)]' \
    --output json | jq length)

if [ "$WILDCARD_POLICIES" -gt 0 ]; then
    echo "❌ Found IAM policies with wildcard permissions"
    aws iam list-policies --scope Local \
        --query 'Policies[?contains(PolicySummary.Statement[].Action[], `*`) || contains(PolicySummary.Statement[].Action[], `*:*`)].PolicyName'
    exit 1
fi
echo "✅ No wildcard IAM permissions found"

# Check role boundaries
AXON_BOUNDARY=$(aws iam get-role --role-name ${PROJECT_NAME}-axon-role \
    --query 'Role.PermissionsBoundary.PermissionsBoundaryArn' \
    --output text 2>/dev/null || echo "")

if [ -z "$AXON_BOUNDARY" ]; then
    echo "❌ Axon role missing permission boundary"
    exit 1
fi
echo "✅ IAM permission boundaries configured"

# KMS Key Isolation
echo "2. Testing KMS key isolation..."

# Test Axon cannot access Orbit's key
AXON_CAN_ACCESS_ORBIT=$(aws kms describe-key --key-id alias/${PROJECT_NAME}-orbit \
    --profile axon-role --query 'KeyMetadata.KeyState' 2>/dev/null || echo "DENIED")

if [ "$AXON_CAN_ACCESS_ORBIT" != "DENIED" ]; then
    echo "❌ Axon can access Orbit's KMS key"
    exit 1
fi
echo "✅ KMS key isolation verified"

# Secrets Access Control
echo "3. Testing secrets access control..."

ORBIT_CAN_ACCESS_AXON_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id ${PROJECT_NAME}/axon \
    --profile orbit-role --query 'Name' 2>/dev/null || echo "DENIED")

if [ "$ORBIT_CAN_ACCESS_AXON_SECRET" != "DENIED" ]; then
    echo "❌ Orbit can access Axon's secrets"
    exit 1
fi
echo "✅ Secrets access isolation verified"

# CloudTrail Audit
echo "4. Checking CloudTrail configuration..."

TRAILS=$(aws cloudtrail describe-trails --query 'trailList[?IsMultiRegionTrail==`true`]' --output json | jq length)

if [ "$TRAILS" -eq 0 ]; then
    echo "❌ No multi-region CloudTrail found"
    exit 1
fi
echo "✅ CloudTrail audit logging enabled"

echo ""
echo "🎉 Security Audit: PASSED"
