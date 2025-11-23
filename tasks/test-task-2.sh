#!/bin/bash
set -e

echo "Testing Task 2: Microservices Development"

# Source environment variables
if [ -f "../.env.local" ]; then
    source ../.env.local
fi

PROJECT_NAME=${PROJECT_NAME:-agent-runtime}

# Test Axon service locally
cd ../services/axon
docker build -t axon-test .
docker run -d --name axon-test -p 8080:80 axon-test
sleep 5

# Test health endpoint
HEALTH_STATUS=$(curl -s http://localhost:8080/health | jq -r .status 2>/dev/null || echo "")
if [ "$HEALTH_STATUS" != "healthy" ]; then
    echo "❌ Axon health check failed"
    docker logs axon-test
    docker stop axon-test
    docker rm axon-test
    exit 1
fi
echo "✅ Axon health check passed"

# Test reason endpoint
REASON_MSG=$(curl -s http://localhost:8080/reason | jq -r .message 2>/dev/null || echo "")
if [ "$REASON_MSG" != "Axon heartbeat OK" ]; then
    echo "❌ Axon reason endpoint failed"
    exit 1
fi
echo "✅ Axon reason endpoint passed"

docker stop axon-test
docker rm axon-test

# Test ECS deployment
CLUSTER_NAME="${PROJECT_NAME}-cluster"
AXON_SERVICE=$(aws ecs describe-services --cluster $CLUSTER_NAME --services ${PROJECT_NAME}-axon --query 'services[0].runningCount' 2>/dev/null || echo 0)
ORBIT_SERVICE=$(aws ecs describe-services --cluster $CLUSTER_NAME --services ${PROJECT_NAME}-orbit --query 'services[0].runningCount' 2>/dev/null || echo 0)

if [ "$AXON_SERVICE" -lt 2 ]; then
    echo "❌ Axon service not running properly"
    exit 1
fi

if [ "$ORBIT_SERVICE" -lt 2 ]; then
    echo "❌ Orbit service not running properly"
    exit 1
fi
echo "✅ Services deployed to ECS"

# Run unit tests
cd ../axon
go test ./tests/unit/... -q
cd ../orbit
go test ./tests/unit/... -q

echo ""
echo "🎉 Task 2 Microservices Development: PASSED"
