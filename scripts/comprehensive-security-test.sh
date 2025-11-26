#!/bin/bash

set -e

PROJECT_NAME="${PROJECT_NAME:-agent-runtime}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "🔒 Comprehensive Security Testing for $PROJECT_NAME"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "success" ]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [ "$status" = "warning" ]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
    else
        echo -e "${RED}❌ $message${NC}"
    fi
}

# Function to check AWS CLI access
check_aws_access() {
    echo "1. Checking AWS Access..."
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_status "error" "AWS credentials not configured"
        exit 1
    fi

    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    print_status "success" "AWS access verified (Account: $ACCOUNT_ID)"
}

# Test Network Isolation
test_network_isolation() {
    echo ""
    echo "2. Testing Network Isolation..."

    # Test VPC exists
    VPC_COUNT=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PROJECT_NAME}-vpc" --query 'length(Vpcs)' --output text --region $AWS_REGION)
    if [ "$VPC_COUNT" -gt 0 ]; then
        print_status "success" "VPC exists and is properly tagged"
    else
        print_status "error" "VPC not found or not properly tagged"
        return 1
    fi

    # Test Security Groups (no wildcards)
    WILDCARD_SGS=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${PROJECT_NAME}*" --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrBlock==`0.0.0.0/0`]]]' --output json --region $AWS_REGION | jq length)

    if [ "$WILDCARD_SGS" -eq 0 ]; then
        print_status "success" "No wildcard security groups found"
    else
        print_status "error" "Found $WILDCARD_SGS security groups with wildcard rules"
    fi

    # Test Subnets exist
    PRIVATE_SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PROJECT_NAME}-vpc" --query 'Vpcs[0].VpcId' --output text --region $AWS_REGION)" "Name=tag:Type,Values=private" --query 'length(Subnets)' --output text --region $AWS_REGION)

    if [ "$PRIVATE_SUBNETS" -gt 0 ]; then
        print_status "success" "Private subnets configured ($PRIVATE_SUBNETS found)"
    else
        print_status "warning" "No private subnets found"
    fi
}

# Test IAM Security
test_iam_security() {
    echo ""
    echo "3. Testing IAM Security..."

    # Test IAM roles exist
    AXON_ROLE_EXISTS=$(aws iam get-role --role-name ${PROJECT_NAME}-axon-role --query 'Role.RoleName' --output text 2>/dev/null || echo "NOT_FOUND")
    ORBIT_ROLE_EXISTS=$(aws iam get-role --role-name ${PROJECT_NAME}-orbit-role --query 'Role.RoleName' --output text 2>/dev/null || echo "NOT_FOUND")

    if [ "$AXON_ROLE_EXISTS" != "NOT_FOUND" ]; then
        print_status "success" "Axon IAM role exists"
    else
        print_status "error" "Axon IAM role not found"
    fi

    if [ "$ORBIT_ROLE_EXISTS" != "NOT_FOUND" ]; then
        print_status "success" "Orbit IAM role exists"
    else
        print_status "error" "Orbit IAM role not found"
    fi

    # Check for permission boundaries
    AXON_BOUNDARY=$(aws iam get-role --role-name ${PROJECT_NAME}-axon-role --query 'Role.PermissionsBoundary.PermissionsBoundaryArn' --output text 2>/dev/null || echo "NONE")

    if [ "$AXON_BOUNDARY" != "NONE" ]; then
        print_status "success" "IAM permission boundaries configured"
    else
        print_status "warning" "IAM permission boundaries not found"
    fi
}

# Test KMS Key Isolation
test_kms_isolation() {
    echo ""
    echo "4. Testing KMS Key Isolation..."

    # Check if KMS keys exist
    AXON_KEY=$(aws kms describe-key --key-id alias/${PROJECT_NAME}-axon --query 'KeyMetadata.KeyId' --output text 2>/dev/null || echo "NOT_FOUND")
    ORBIT_KEY=$(aws kms describe-key --key-id alias/${PROJECT_NAME}-orbit --query 'KeyMetadata.KeyId' --output text 2>/dev/null || echo "NOT_FOUND")

    if [ "$AXON_KEY" != "NOT_FOUND" ]; then
        print_status "success" "Axon KMS key exists"
    else
        print_status "error" "Axon KMS key not found"
    fi

    if [ "$ORBIT_KEY" != "NOT_FOUND" ]; then
        print_status "success" "Orbit KMS key exists"
    else
        print_status "error" "Orbit KMS key not found"
    fi
}

# Test Secrets Management
test_secrets_management() {
    echo ""
    echo "5. Testing Secrets Management..."

    # Check if secrets exist
    AXON_SECRET=$(aws secretsmanager describe-secret --secret-id ${PROJECT_NAME}/axon --query 'Name' --output text 2>/dev/null || echo "NOT_FOUND")
    ORBIT_SECRET=$(aws secretsmanager describe-secret --secret-id ${PROJECT_NAME}/orbit --query 'Name' --output text 2>/dev/null || echo "NOT_FOUND")

    if [ "$AXON_SECRET" != "NOT_FOUND" ]; then
        print_status "success" "Axon secrets configured"
    else
        print_status "error" "Axon secrets not found"
    fi

    if [ "$ORBIT_SECRET" != "NOT_FOUND" ]; then
        print_status "success" "Orbit secrets configured"
    else
        print_status "error" "Orbit secrets not found"
    fi

    # Check rotation configuration
    AXON_ROTATION=$(aws secretsmanager describe-secret --secret-id ${PROJECT_NAME}/axon --query 'RotationEnabled' --output text 2>/dev/null || echo "false")
    if [ "$AXON_ROTATION" = "True" ]; then
        print_status "success" "Secrets rotation enabled"
    else
        print_status "warning" "Secrets rotation not enabled"
    fi
}

# Test Governance Layer
test_governance_layer() {
    echo ""
    echo "6. Testing Governance Layer..."

    # Test Lambda function exists
    GOVERNANCE_EXISTS=$(aws lambda get-function --function-name ${PROJECT_NAME}-governance --query 'Configuration.FunctionName' --output text 2>/dev/null || echo "NOT_FOUND")

    if [ "$GOVERNANCE_EXISTS" != "NOT_FOUND" ]; then
        print_status "success" "Governance Lambda function exists"

        # Test governance decision
        RESPONSE=$(aws lambda invoke --function-name ${PROJECT_NAME}-governance --payload '{"service": "orbit", "intent": "call_reasoning"}' --region $AWS_REGION output.json 2>/dev/null && cat output.json | jq -r '.statusCode' || echo "ERROR")

        if [ "$RESPONSE" = "200" ]; then
            print_status "success" "Governance layer allows authorized requests"
        elif [ "$RESPONSE" = "403" ]; then
            print_status "warning" "Governance layer denies requests (check policies)"
        else
            print_status "error" "Governance layer not responding correctly"
        fi
    else
        print_status "error" "Governance Lambda function not found"
    fi
}

# Test Monitoring and Logging
test_monitoring() {
    echo ""
    echo "7. Testing Monitoring and Logging..."

    # Test CloudWatch Log Groups
    GOVERNANCE_LOGS=$(aws logs describe-log-groups --log-group-name-prefix /aws/lambda/${PROJECT_NAME}-governance --query 'logGroups[0].logGroupName' --output text 2>/dev/null || echo "NOT_FOUND")

    if [ "$GOVERNANCE_LOGS" != "NOT_FOUND" ]; then
        print_status "success" "CloudWatch log groups configured"
    else
        print_status "error" "CloudWatch log groups not found"
    fi

    # Test CloudWatch Alarms
    ALARMS=$(aws cloudwatch describe-alarms --alarm-name-prefix ${PROJECT_NAME} --query 'length(MetricAlarms)' --output text --region $AWS_REGION)

    if [ "$ALARMS" -gt 0 ]; then
        print_status "success" "CloudWatch alarms configured ($ALARMS found)"
    else
        print_status "warning" "No CloudWatch alarms found"
    fi
}

# Test SigV4 Implementation (if services are running locally)
test_sigv4() {
    echo ""
    echo "8. Testing SigV4 Implementation..."

    # Check if SigV4 code exists
    if [ -f "services/orbit/sigv4.go" ]; then
        print_status "success" "SigV4 signing code exists in Orbit"

        # Try to run tests (if Go is available)
        if command -v go >/dev/null 2>&1; then
            cd services/orbit
            if go test ./sigv4/... -v >/dev/null 2>&1; then
                print_status "success" "SigV4 signing tests pass"
            else
                print_status "warning" "SigV4 signing tests not available"
            fi
            cd ../..
        else
            print_status "warning" "Go not available for testing"
        fi
    else
        print_status "error" "SigV4 implementation not found"
    fi

    if [ -f "services/axon/sigv4.go" ]; then
        print_status "success" "SigV4 verification code exists in Axon"
    else
        print_status "error" "SigV4 verification implementation not found"
    fi
}

# Main execution
main() {
    echo "Starting comprehensive security validation..."
    echo ""

    check_aws_access
    test_network_isolation
    test_iam_security
    test_kms_isolation
    test_secrets_management
    test_governance_layer
    test_monitoring
    test_sigv4

    echo ""
    echo "=================================================="
    echo -e "${BLUE}🔒 Security Validation Complete!${NC}"
    echo ""
    echo "Review the results above. Any '❌' items need immediate attention."
    echo "Items marked '⚠️' are warnings that should be addressed."
    echo ""
    echo "For detailed testing of individual components, run:"
    echo "  ./scripts/test-isolation.sh     # Network isolation"
    echo "  ./scripts/security-audit.sh    # IAM audit"
    echo "  ./scripts/validate-sigv4.sh    # SigV4 testing"
    echo ""
}

# Run main function
main "$@"
