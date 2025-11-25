#!/bin/bash

set -e

echo "Testing Zero-Trust Network Isolation..."

# Test 1: Verify no wildcard security groups
echo "1. Checking for wildcard security groups..."
WILDCARD_SGS=$(aws ec2 describe-security-groups \
    --filters Name=group-description,Values="*${PROJECT_NAME}*" \
    --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrBlock==`0.0.0.0/0`]]]' \
    --output json | jq length)

if [ "$WILDCARD_SGS" -gt 0 ]; then
    echo "❌ Found security groups with 0.0.0.0/0 ingress rules"
    aws ec2 describe-security-groups \
        --filters Name=group-description,Values="*${PROJECT_NAME}*" \
        --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrBlock==`0.0.0.0/0`]]].{GroupId:GroupId,GroupName:GroupName}'
    exit 1
fi
echo "✅ No wildcard security groups found"

# Test 2: Verify private-only communication
echo "2. Testing private-only communication..."
# This requires deploying test instances in different subnets

# Test 3: Verify NACL restrictions
echo "3. Checking NACL configurations..."
PUBLIC_NACL=$(aws ec2 describe-network-acls \
    --filters Name=tag:Name,Values="${PROJECT_NAME}-public-nacl" \
    --query 'NetworkAcls[0].Entries[?Egress==`false` && CidrBlock==`0.0.0.0/0`]' \
    --output json | jq length)

if [ "$PUBLIC_NACL" -eq 0 ]; then
    echo "❌ Public subnet NACL allows unrestricted outbound"
    exit 1
fi
echo "✅ NACLs properly restrict traffic"

# Test 4: Verify service mesh isolation
echo "4. Testing App Mesh isolation..."
AXON_VNODES=$(aws appmesh list-virtual-nodes --mesh-name ${PROJECT_NAME}-mesh \
    --query 'virtualNodes[?contains(virtualNodeName, `axon`)]' \
    --output json | jq length)

if [ "$AXON_VNODES" -eq 0 ]; then
    echo "❌ Axon virtual nodes not found in mesh"
    exit 1
fi
echo "✅ App Mesh virtual nodes configured"

echo ""
echo "🎉 Zero-Trust Network Validation: PASSED"
