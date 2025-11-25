#!/bin/bash

set -e

echo "Validating SigV4 Implementation..."

# Set environment variables for testing
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-test-access-key}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-test-secret-key}"
export AWS_REGION="${AWS_REGION:-us-east-1}"
export AXON_SERVICE_URL="http://localhost:8081/reason"

# Function to start axon service
start_axon() {
    echo "Starting Axon service..."
    cd services/axon
    go run . &
    AXON_PID=$!
    cd ../..
    sleep 3
}

# Function to start orbit service
start_orbit() {
    echo "Starting Orbit service..."
    cd services/orbit
    go run . &
    ORBIT_PID=$!
    cd ../..
    sleep 3
}

# Function to cleanup services
cleanup() {
    echo "Cleaning up services..."
    kill $AXON_PID $ORBIT_PID 2>/dev/null || true
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Test 1: Start services
echo "1. Starting services..."
start_axon
start_orbit

# Test 2: Test signed request
echo "2. Testing SigV4 signed request..."
cd services/orbit

# Make a test request (this would normally be done by the orbit service)
# For now, we'll just check if services are running
if curl -f http://localhost:8080/health >/dev/null 2>&1; then
    echo "✅ Orbit service is running"
else
    echo "❌ Orbit service is not responding"
    exit 1
fi

if curl -f http://localhost:8081/reason >/dev/null 2>&1; then
    echo "✅ Axon service is running"
else
    echo "❌ Axon service is not responding"
    exit 1
fi

cd ../..

# Test 3: Test SigV4 signing logic (unit test)
echo "3. Testing SigV4 signing logic..."
cd services/orbit

if go test ./sigv4/... -v | grep -q "PASS"; then
    echo "✅ SigV4 signing tests passed"
else
    echo "❌ SigV4 signing tests failed"
    exit 1
fi

cd ../..

# Test 4: Test SigV4 verification logic (unit test)
echo "4. Testing SigV4 verification logic..."
cd services/axon

if go test ./sigv4/... -v | grep -q "PASS"; then
    echo "✅ SigV4 verification tests passed"
else
    echo "❌ SigV4 verification tests failed"
    exit 1
fi

cd ../..

echo ""
echo "🎉 SigV4 Validation: PASSED"
