#!/bin/bash
set -e

echo "Testing Task 3: Governance Layer"

PROJECT_NAME=${PROJECT_NAME:-agent-runtime}

# Test Lambda function exists
FUNCTION_NAME="${PROJECT_NAME}-governance"
FUNCTION_EXISTS=$(aws lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.State' 2>/dev/null || echo "Failed")

if [ "$FUNCTION_EXISTS" == "Failed" ]; then
    echo "❌ Governance Lambda function not found"
    exit 1
fi
echo "✅ Governance Lambda function exists"

# Test DynamoDB table exists
TABLE_NAME="${PROJECT_NAME}-governance-policies"
TABLE_EXISTS=$(aws dynamodb describe-table --table-name $TABLE_NAME --query 'Table.TableStatus' 2>/dev/null || echo "Failed")

if [ "$TABLE_EXISTS" == "Failed" ]; then
    echo "❌ Governance DynamoDB table not found"
    exit 1
fi
echo "✅ Governance DynamoDB table exists"

# Test governance API - allowed request
RESPONSE=$(aws lambda invoke --function-name $FUNCTION_NAME \
  --payload '{"service": "orbit", "intent": "call_reasoning"}' \
  --query 'Payload' \
  output.json 2>/dev/null)

ALLOWED=$(cat output.json | jq -r '.allowed' 2>/dev/null || echo "")
if [ "$ALLOWED" != "true" ]; then
    echo "❌ Governance should allow orbit:call_reasoning"
    cat output.json
    exit 1
fi
echo "✅ Governance allows authorized requests"

# Test governance API - denied request (unknown intent)
RESPONSE=$(aws lambda invoke --function-name $FUNCTION_NAME \
  --payload '{"service": "orbit", "intent": "unknown_intent"}' \
  --query 'Payload' \
  output.json 2>/dev/null)

ALLOWED=$(cat output.json | jq -r '.allowed' 2>/dev/null || echo "")
if [ "$ALLOWED" != "false" ]; then
    echo "❌ Governance should deny unknown intents"
    exit 1
fi
echo "✅ Governance denies unauthorized requests"

# Test policies loaded
POLICY_COUNT=$(aws dynamodb scan --table-name $TABLE_NAME --query 'Count' 2>/dev/null || echo 0)
if [ "$POLICY_COUNT" -lt 1 ]; then
    echo "❌ No policies found in DynamoDB"
    exit 1
fi
echo "✅ Policies loaded in DynamoDB"

# Run unit tests
cd ../governance/lambda
python -m pytest tests/unit/ -q

echo ""
echo "🎉 Task 3 Governance Layer: PASSED"
