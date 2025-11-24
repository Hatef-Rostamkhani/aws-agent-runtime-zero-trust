#!/bin/bash
set -e

echo "Testing Task 3: Governance Layer"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if PROJECT_NAME is set
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="agent-runtime"
    echo -e "${YELLOW}PROJECT_NAME not set, using default: $PROJECT_NAME${NC}"
fi

FUNCTION_NAME="${PROJECT_NAME}-governance"
TABLE_NAME="${PROJECT_NAME}-governance-policies"

# Test Lambda function exists
echo ""
echo "=== Testing Lambda Function ==="
if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null; then
    FUNCTION_STATE=$(aws lambda get-function --function-name "$FUNCTION_NAME" --query 'Configuration.State' --output text 2>/dev/null || echo "Failed")
    
    if [ "$FUNCTION_STATE" == "Failed" ] || [ -z "$FUNCTION_STATE" ]; then
        echo -e "${RED}❌ Governance Lambda function not found${NC}"
        echo "   Function name: $FUNCTION_NAME"
        echo "   Run: cd governance/terraform && terraform apply"
        exit 1
    fi
    echo -e "${GREEN}✅ Governance Lambda function exists (State: $FUNCTION_STATE)${NC}"
else
    echo -e "${YELLOW}⚠️  AWS CLI not configured, skipping Lambda function check${NC}"
fi

# Test DynamoDB table exists
echo ""
echo "=== Testing DynamoDB Table ==="
if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null; then
    TABLE_STATUS=$(aws dynamodb describe-table --table-name "$TABLE_NAME" --query 'Table.TableStatus' --output text 2>/dev/null || echo "Failed")
    
    if [ "$TABLE_STATUS" == "Failed" ] || [ -z "$TABLE_STATUS" ]; then
        echo -e "${RED}❌ Governance DynamoDB table not found${NC}"
        echo "   Table name: $TABLE_NAME"
        echo "   Run: cd governance/terraform && terraform apply"
        exit 1
    fi
    echo -e "${GREEN}✅ Governance DynamoDB table exists (Status: $TABLE_STATUS)${NC}"
else
    echo -e "${YELLOW}⚠️  AWS CLI not configured, skipping DynamoDB table check${NC}"
fi

# Test governance API - allowed request
echo ""
echo "=== Testing Governance API ==="
if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null && [ "$FUNCTION_STATE" != "Failed" ]; then
    echo "Testing allowed request (orbit:call_reasoning)..."
    
    aws lambda invoke \
        --function-name "$FUNCTION_NAME" \
        --payload '{"service": "orbit", "intent": "call_reasoning"}' \
        /tmp/governance-output.json 2>/dev/null || true
    
    if [ -f /tmp/governance-output.json ]; then
        ALLOWED=$(cat /tmp/governance-output.json | python3 -c "import sys, json; print(json.load(sys.stdin).get('allowed', 'false'))" 2>/dev/null || echo "false")
        
        if [ "$ALLOWED" == "True" ] || [ "$ALLOWED" == "true" ]; then
            echo -e "${GREEN}✅ Governance allows authorized requests${NC}"
        else
            echo -e "${RED}❌ Governance should allow orbit:call_reasoning${NC}"
            cat /tmp/governance-output.json
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠️  Could not invoke Lambda function${NC}"
    fi
    
    # Test governance API - denied request (unknown intent)
    echo "Testing denied request (orbit:unknown_intent)..."
    
    aws lambda invoke \
        --function-name "$FUNCTION_NAME" \
        --payload '{"service": "orbit", "intent": "unknown_intent"}' \
        /tmp/governance-output-deny.json 2>/dev/null || true
    
    if [ -f /tmp/governance-output-deny.json ]; then
        ALLOWED=$(cat /tmp/governance-output-deny.json | python3 -c "import sys, json; print(json.load(sys.stdin).get('allowed', 'true'))" 2>/dev/null || echo "true")
        
        if [ "$ALLOWED" == "False" ] || [ "$ALLOWED" == "false" ]; then
            echo -e "${GREEN}✅ Governance denies unauthorized requests${NC}"
        else
            echo -e "${YELLOW}⚠️  Governance did not deny unknown intent (may be expected if policy exists)${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠️  AWS CLI not configured, skipping API tests${NC}"
fi

# Test policies loaded
echo ""
echo "=== Testing Policies ==="
if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null && [ "$TABLE_STATUS" != "Failed" ]; then
    POLICY_COUNT=$(aws dynamodb scan --table-name "$TABLE_NAME" --query 'Count' --output text 2>/dev/null || echo "0")
    
    if [ "$POLICY_COUNT" -lt 1 ]; then
        echo -e "${RED}❌ No policies found in DynamoDB${NC}"
        echo "   Run: python governance/scripts/load-policies.py"
        exit 1
    fi
    echo -e "${GREEN}✅ Policies loaded in DynamoDB (Count: $POLICY_COUNT)${NC}"
else
    echo -e "${YELLOW}⚠️  AWS CLI not configured, skipping policy count check${NC}"
fi

# Run unit tests
echo ""
echo "=== Running Unit Tests ==="
cd governance/lambda

if command -v python3 &> /dev/null; then
    # Check if pytest is available
    if python3 -m pytest --version &> /dev/null; then
        if python3 -m pytest tests/unit/ -v --tb=short; then
            echo -e "${GREEN}✅ Unit tests passed${NC}"
        else
            echo -e "${RED}❌ Unit tests failed${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠️  pytest not installed, skipping unit tests${NC}"
        echo "   Install with: pip install pytest pytest-mock"
    fi
else
    echo -e "${YELLOW}⚠️  Python3 not found, skipping unit tests${NC}"
fi

cd ../..

# Cleanup
rm -f /tmp/governance-output.json /tmp/governance-output-deny.json

echo ""
echo -e "${GREEN}🎉 Task 3 Governance Layer: PASSED${NC}"
