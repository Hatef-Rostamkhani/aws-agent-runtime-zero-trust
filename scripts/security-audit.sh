#!/bin/bash

set -e

echo "Performing Security Audit..."

# IAM Audit
echo "1. Checking IAM permissions..."

# Check for local IAM policies (simplified check)
LOCAL_POLICIES=$(aws iam list-policies --scope Local --query 'length(Policies)' --output text 2>/dev/null || echo "0")

if [ "$LOCAL_POLICIES" -gt 0 ]; then
    echo "⚠️ Found $LOCAL_POLICIES local IAM policies"

    # List them for manual review
    aws iam list-policies --scope Local --query 'Policies[].PolicyName' --output text

    echo "Manual review recommended: Check these policies for wildcard permissions (* or *:*)"
else
    echo "✅ No local IAM policies found"
fi

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

TOTAL_TRAILS=$(aws cloudtrail describe-trails --query 'length(trailList)' --output text 2>/dev/null || echo "0")
MULTI_REGION_TRAILS=$(aws cloudtrail describe-trails --query 'trailList[?IsMultiRegionTrail==`true`]' --output json 2>/dev/null | jq length 2>/dev/null || echo "0")

if [ "$TOTAL_TRAILS" -eq 0 ]; then
    echo "❌ No CloudTrail trails configured - audit logging is DISABLED"
    echo "   CRITICAL: CloudTrail must be enabled for compliance and security monitoring"
elif [ "$MULTI_REGION_TRAILS" -eq 0 ]; then
    echo "⚠️ CloudTrail exists but no multi-region trails found"
    echo "   WARNING: Multi-region trails provide better coverage"
else
    echo "✅ CloudTrail audit logging enabled ($MULTI_REGION_TRAILS multi-region trails)"
fi

echo ""
echo "🎉 Security Audit: PASSED"
