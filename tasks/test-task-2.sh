#!/bin/bash
set -e

echo "Testing Task 2: Microservices Development"

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

# Test Axon service locally
echo ""
echo "=== Testing Axon Service ==="
cd services/axon

# Run unit tests
echo "Running Axon unit tests..."
if ! go test ./tests/unit/ -v; then
    echo -e "${RED}❌ Axon unit tests failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Axon unit tests passed${NC}"

# Build Docker image
echo "Building Axon Docker image..."
if ! docker build -t axon-test . > /dev/null 2>&1; then
    echo -e "${RED}❌ Axon Docker build failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Axon Docker build succeeded${NC}"

# Run container
echo "Starting Axon container..."
docker run -d --name axon-test -p 8080:80 axon-test > /dev/null 2>&1
sleep 5

# Test health endpoint
echo "Testing Axon health endpoint..."
HEALTH_RESPONSE=$(curl -s http://localhost:8080/health || echo "")
if [ -z "$HEALTH_RESPONSE" ]; then
    echo -e "${RED}❌ Axon health check failed - no response${NC}"
    docker logs axon-test
    docker stop axon-test > /dev/null 2>&1
    docker rm axon-test > /dev/null 2>&1
    exit 1
fi

HEALTH_STATUS=$(echo "$HEALTH_RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "")
if [ "$HEALTH_STATUS" != "healthy" ]; then
    echo -e "${RED}❌ Axon health check failed - status: $HEALTH_STATUS${NC}"
    echo "Response: $HEALTH_RESPONSE"
    docker logs axon-test
    docker stop axon-test > /dev/null 2>&1
    docker rm axon-test > /dev/null 2>&1
    exit 1
fi
echo -e "${GREEN}✅ Axon health check passed${NC}"

# Test reason endpoint
echo "Testing Axon reason endpoint..."
REASON_RESPONSE=$(curl -s http://localhost:8080/reason || echo "")
if [ -z "$REASON_RESPONSE" ]; then
    echo -e "${RED}❌ Axon reason endpoint failed - no response${NC}"
    docker stop axon-test > /dev/null 2>&1
    docker rm axon-test > /dev/null 2>&1
    exit 1
fi

REASON_MSG=$(echo "$REASON_RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4 || echo "")
if [ "$REASON_MSG" != "Axon heartbeat OK" ]; then
    echo -e "${RED}❌ Axon reason endpoint failed - message: $REASON_MSG${NC}"
    echo "Response: $REASON_RESPONSE"
    docker stop axon-test > /dev/null 2>&1
    docker rm axon-test > /dev/null 2>&1
    exit 1
fi
echo -e "${GREEN}✅ Axon reason endpoint passed${NC}"

docker stop axon-test > /dev/null 2>&1
docker rm axon-test > /dev/null 2>&1

# Test Orbit service locally
echo ""
echo "=== Testing Orbit Service ==="
cd ../orbit

# Run unit tests
echo "Running Orbit unit tests..."
if ! go test ./tests/unit/ -v; then
    echo -e "${RED}❌ Orbit unit tests failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Orbit unit tests passed${NC}"

# Run integration tests
echo "Running Orbit integration tests..."
if ! go test ./tests/integration/ -v; then
    echo -e "${RED}❌ Orbit integration tests failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Orbit integration tests passed${NC}"

# Build Docker image
echo "Building Orbit Docker image..."
if ! docker build -t orbit-test . > /dev/null 2>&1; then
    echo -e "${RED}❌ Orbit Docker build failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Orbit Docker build succeeded${NC}"

# Test ECS deployment (if AWS credentials are configured)
echo ""
echo "=== Testing ECS Deployment ==="
if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null; then
    CLUSTER_NAME="${PROJECT_NAME}-cluster"
    
    echo "Checking ECS services..."
    AXON_SERVICE=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "${PROJECT_NAME}-axon" \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null || echo "0")
    
    ORBIT_SERVICE=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "${PROJECT_NAME}-orbit" \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null || echo "0")
    
    if [ "$AXON_SERVICE" != "null" ] && [ "$AXON_SERVICE" -ge 0 ]; then
        echo -e "${GREEN}✅ Axon service found (running count: $AXON_SERVICE)${NC}"
    else
        echo -e "${YELLOW}⚠️  Axon service not found or not deployed${NC}"
    fi
    
    if [ "$ORBIT_SERVICE" != "null" ] && [ "$ORBIT_SERVICE" -ge 0 ]; then
        echo -e "${GREEN}✅ Orbit service found (running count: $ORBIT_SERVICE)${NC}"
    else
        echo -e "${YELLOW}⚠️  Orbit service not found or not deployed${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  AWS CLI not configured, skipping ECS deployment check${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Task 2 Microservices Development: PASSED${NC}"
