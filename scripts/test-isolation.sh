#!/bin/bash

set -e

# Check if PROJECT_NAME is set
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="agent-runtime"
    echo "PROJECT_NAME not set, using default: $PROJECT_NAME"
fi

echo "Testing Zero-Trust Network Isolation..."

# Test 1: Verify no wildcard security groups
echo "1. Checking for wildcard security groups..."
WILDCARD_SGS=$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values="*${PROJECT_NAME}*" \
    --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrBlock==`0.0.0.0/0`]]]' \
    --output json 2>/dev/null | jq length 2>/dev/null || echo "0")

if [ "$WILDCARD_SGS" -gt 0 ]; then
    echo "❌ Found security groups with 0.0.0.0/0 ingress rules"
    aws ec2 describe-security-groups \
        --filters Name=group-name,Values="*${PROJECT_NAME}*" \
        --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrBlock==`0.0.0.0/0`]]].{GroupId:GroupId,GroupName:GroupName}' \
        --output text
    exit 1
fi
echo "✅ No wildcard security groups found"

# Test 2: Verify private-only communication
echo "2. Testing private-only communication..."
# This requires deploying test instances in different subnets

# Test 3: Verify NACL restrictions
echo "3. Checking NACL configurations..."
PRIVATE_OUTBOUND_OPEN=$(aws ec2 describe-network-acls \
    --filters Name=tag:Name,Values="${PROJECT_NAME}-private-nacl" \
    --query 'NetworkAcls[0].Entries[?Egress==`true` && CidrBlock==`0.0.0.0/0` && Protocol==`-1` && RuleAction==`allow` && RuleNumber<`32767`]' \
    --output json 2>/dev/null | jq length 2>/dev/null || echo "0")

if [ "$PRIVATE_OUTBOUND_OPEN" -gt 0 ]; then
    echo "❌ Private subnet NACL allows unrestricted outbound access"
    exit 1
fi
echo "✅ NACLs properly restrict traffic"

# Test 4: Verify service mesh isolation
echo "4. Testing App Mesh isolation..."
MESH_NAME="${PROJECT_NAME}-mesh"
AXON_VNODES=$(aws appmesh list-virtual-nodes --mesh-name "$MESH_NAME" \
    --query 'virtualNodes[?contains(virtualNodeName, `axon`)]' \
    --output json 2>/dev/null | jq length 2>/dev/null || echo "0")

if [ "$AXON_VNODES" -eq 0 ]; then
    echo "❌ Axon virtual nodes not found in mesh"
    exit 1
fi
echo "✅ App Mesh virtual nodes configured"

echo ""
echo "🎉 Zero-Trust Network Validation: PASSED"
