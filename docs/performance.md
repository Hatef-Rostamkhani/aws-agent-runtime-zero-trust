# Performance Characteristics

This document outlines the performance characteristics, benchmarks, and optimization guidelines for the AWS Agent Runtime system.

## System Specifications

### Infrastructure Baseline

- **ECS Tasks**: 2-10 tasks per service
- **CPU Allocation**: 0.25-2 vCPU per task
- **Memory Allocation**: 512MB-4GB per task
- **Lambda Memory**: 128MB-1024MB
- **DynamoDB**: On-demand or provisioned capacity

### Network Specifications

- **ALB**: Application Load Balancer
- **App Mesh**: Service-to-service communication
- **VPC**: Private subnets with NAT gateways
- **Regions**: Multi-AZ deployment (3 AZs)

## Performance Benchmarks

### API Response Times

#### Health Check Endpoint (GET /health)
- **p50**: 15-25ms
- **p95**: 50-75ms
- **p99**: 100-150ms

#### Dispatch Endpoint (POST /dispatch)
- **p50**: 100-200ms (including governance)
- **p95**: 300-500ms
- **p99**: 750-1000ms

### Throughput Targets

- **Sustained Load**: 1000 requests/minute
- **Peak Load**: 2000 requests/minute
- **Concurrent Users**: 100 simultaneous connections

### Resource Utilization

#### ECS Tasks
- **CPU**: 20-70% average utilization
- **Memory**: 40-80% average utilization
- **Network I/O**: < 10MB/s per task

#### Lambda Functions
- **Duration**: 50-200ms per invocation
- **Concurrent Executions**: 10-100
- **Memory Usage**: 64-256MB

#### Database
- **Read Capacity**: 100-1000 RCU
- **Write Capacity**: 50-500 WCU
- **Throttling**: < 1% of requests

## Performance Monitoring

### Key Metrics

#### Response Time Metrics
```bash
# API response times
aws cloudwatch get-metric-statistics \
    --namespace ${PROJECT_NAME}/API \
    --metric-name ResponseTime \
    --statistics p50,p95,p99 \
    --start-time $(date -u -d '1 hour ago' +%s)

# Governance decision times
aws cloudwatch get-metric-statistics \
    --namespace ${PROJECT_NAME}/Governance \
    --metric-name DecisionTime \
    --statistics Average \
    --start-time $(date -u -d '1 hour ago' +%s)
```

#### Throughput Metrics
```bash
# Request rate
aws cloudwatch get-metric-statistics \
    --namespace AWS/ApplicationELB \
    --metric-name RequestCount \
    --statistics Sum \
    --start-time $(date -u -d '1 hour ago' +%s)

# Error rates
aws cloudwatch get-metric-statistics \
    --namespace ${PROJECT_NAME}/API \
    --metric-name ErrorRate \
    --statistics Average \
    --start-time $(date -u -d '1 hour ago' +%s)
```

### Performance Dashboard

```
┌─────────────────────────────────────────────────────────────┐
│                     Performance Dashboard                  │
├─────────────────────────────────────────────────────────────┤
│ Response Times      │ Throughput     │ Error Rate │ Status │
│ p50: 150ms          │ 850 req/min    │ 0.05%      │ ✅ OK  │
│ p95: 350ms          │ Peak: 1200/min │ 5xx: 0.01% │        │
│ p99: 800ms          │                │ 4xx: 0.04% │        │
├─────────────────────────────────────────────────────────────┤
│ Resource Utilization                                      │
│ ECS CPU: 45%        │ Lambda Duration: 120ms │ DB Throttle: 0% │
│ ECS Memory: 60%     │ Lambda Memory: 128MB   │               │
└─────────────────────────────────────────────────────────────┘
```

## Load Testing

### Test Scenarios

#### Baseline Load Test
```bash
# Install hey (load testing tool)
# Test with 10 concurrent users for 5 minutes
hey -n 3000 -c 10 -m POST \
    -H "Content-Type: application/json" \
    -d '{"intent": "call_reasoning", "context": {"user_id": "test"}}' \
    https://$ALB_DNS/dispatch
```

#### Stress Test
```bash
# Gradual load increase
for concurrency in 10 25 50 100; do
    echo "Testing with $concurrency concurrent users"
    hey -n 1000 -c $concurrency -m POST \
        -d '{"intent": "call_reasoning"}' \
        https://$ALB_DNS/dispatch
    sleep 30
done
```

#### Spike Test
```bash
# Sudden traffic spike
hey -n 5000 -c 50 -q 10 -m POST \
    -d '{"intent": "call_reasoning"}' \
    https://$ALB_DNS/dispatch
```

### Load Test Results Template

```markdown
# Load Test Results: [Date]

## Test Configuration
- **Duration**: 10 minutes
- **Concurrency**: 50 users
- **Total Requests**: 30,000
- **Ramp-up**: 1 minute

## Results

### Response Times
- **Average**: 245ms
- **p95**: 480ms
- **p99**: 890ms
- **Max**: 2.1s

### Throughput
- **Requests/second**: 50
- **Total requests**: 30,000
- **Success rate**: 99.7%

### Resource Utilization
- **ECS CPU**: Peak 75%, Average 55%
- **ECS Memory**: Peak 80%, Average 65%
- **Lambda Duration**: Average 150ms
- **DynamoDB Throttles**: 0

### Error Analysis
- **4xx Errors**: 45 (0.15%)
- **5xx Errors**: 12 (0.04%)
- **Timeouts**: 8 (0.03%)

## Recommendations
- [ ] Increase ECS task count to 4 for sustained load
- [ ] Optimize governance policy cache
- [ ] Consider API Gateway caching for static responses
```

## Performance Optimization

### ECS Optimization

#### Task Sizing
```bash
# Right-size based on metrics
aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN \
    --query 'tasks[0].{cpu:cpu,memory:memory}'

# Update task definition
aws ecs register-task-definition \
    --cli-input-json file://optimized-task-def.json

# Deploy updated version
aws ecs update-service --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --force-new-deployment
```

#### Auto-scaling Configuration
```hcl
resource "aws_appautoscaling_policy" "cpu_scaling" {
  name               = "${var.project_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 60.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
```

### Lambda Optimization

#### Memory and Timeout Tuning
```bash
# Test different memory configurations
for memory in 128 256 512 1024; do
    aws lambda update-function-configuration \
        --function-name ${PROJECT_NAME}-governance \
        --memory-size $memory

    # Run performance test
    hey -n 1000 -c 10 -m POST \
        -d '{"intent": "call_reasoning"}' \
        https://$ALB_DNS/dispatch

    # Measure duration
    aws cloudwatch get-metric-statistics \
        --namespace AWS/Lambda \
        --metric-name Duration \
        --statistics Average \
        --start-time $(date -u -d '5 minutes ago' +%s)
done
```

#### Provisioned Concurrency
```bash
# Enable provisioned concurrency for predictable performance
aws lambda put-provisioned-concurrency-config \
    --function-name ${PROJECT_NAME}-governance \
    --qualifier $ALIAS \
    --provisioned-concurrent-executions 10
```

### Database Optimization

#### DynamoDB Capacity Planning
```bash
# Monitor usage patterns
aws dynamodb describe-table --table-name ${PROJECT_NAME}-governance-policies \
    --query 'Table.{ReadCapacityUnits:ProvisionedThroughput.ReadCapacityUnits,WriteCapacityUnits:ProvisionedThroughput.WriteCapacityUnits}'

# Switch to on-demand for variable workloads
aws dynamodb update-table --table-name ${PROJECT_NAME}-governance-policies \
    --billing-mode PAY_PER_REQUEST
```

#### Query Optimization
```python
# Use query instead of scan
response = dynamodb.query(
    TableName='governance-policies',
    KeyConditionExpression='pk = :pk',
    ExpressionAttributeValues={
        ':pk': {'S': f'POLICY#{policy_id}'}
    }
)
```

### Network Optimization

#### Connection Pooling
```go
// Configure HTTP client with connection pooling
client := &http.Client{
    Transport: &http.Transport{
        MaxIdleConns:        100,
        MaxIdleConnsPerHost: 10,
        IdleConnTimeout:     90 * time.Second,
    },
    Timeout: 30 * time.Second,
}
```

#### Keep-Alive Settings
```nginx
# ALB configuration for keep-alive
keepalive_timeout 65;
keepalive_requests 100;
```

## Caching Strategies

### API Gateway Caching
```bash
# Enable response caching for health endpoints
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name prod \
    --variables 'cachingEnabled=true'
```

### Application-Level Caching
```go
// Implement in-memory cache for frequent lookups
type Cache struct {
    data   map[string]interface{}
    mutex  sync.RWMutex
    ttl    time.Duration
}

func (c *Cache) Get(key string) (interface{}, bool) {
    c.mutex.RLock()
    defer c.mutex.RUnlock()

    if item, exists := c.data[key]; exists {
        return item, true
    }
    return nil, false
}
```

### CDN Integration
```hcl
# CloudFront distribution for static assets
resource "aws_cloudfront_distribution" "api_docs" {
  origin {
    domain_name = aws_s3_bucket.docs.bucket_regional_domain_name
    origin_id   = "docs-origin"
  }

  default_cache_behavior {
    target_origin_id = "docs-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }
}
```

## Cost Optimization

### Resource Rightsizing

#### ECS Cost Optimization
```bash
# Calculate optimal task size
aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN \
    --query 'tasks[0].{cpu:cpu,memory:memory,lastStatus:lastStatus}'

# Monitor usage over time
aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name CPUUtilization \
    --statistics Average,Maximum \
    --start-time $(date -u -d '7 days ago' +%s) \
    --period 3600
```

#### Lambda Cost Optimization
```bash
# Analyze Lambda costs
aws ce get-cost-and-usage \
    --time-period Start=2024-01-01,End=2024-01-31 \
    --granularity DAILY \
    --metrics "BlendedCost" \
    --group-by Type=DIMENSION,Key=SERVICE \
    --filter '{
        "Dimensions": {
            "Key": "SERVICE",
            "Values": ["AWS Lambda"]
        }
    }'
```

### Auto-scaling Policies

#### Scale-to-Zero
```hcl
# Scale down to zero during low usage
resource "aws_appautoscaling_policy" "scale_to_zero" {
  name               = "${var.project_name}-scale-to-zero"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 5.0
    scale_in_cooldown  = 1800  # 30 minutes
  }
}
```

## Performance Testing Automation

### Continuous Performance Testing
```bash
#!/bin/bash
# scripts/performance-test.sh

echo "🚀 Running Performance Tests"

# Install tools
go install github.com/rakyll/hey@latest

# Run baseline test
echo "Running baseline performance test..."
hey -n 1000 -c 10 -m POST \
    -H "Content-Type: application/json" \
    -d '{"intent": "call_reasoning"}' \
    https://$ALB_DNS/dispatch > baseline.txt

# Parse results
avg_response=$(grep "average" baseline.txt | awk '{print $2}')
p95_response=$(grep "95%" baseline.txt | awk '{print $2}')

# Check thresholds
if (( $(echo "$p95_response > 500" | bc -l) )); then
    echo "❌ Performance degraded: p95 = ${p95_response}ms"
    exit 1
else
    echo "✅ Performance within thresholds: p95 = ${p95_response}ms"
fi
```

### Performance Regression Detection
```python
# scripts/performance-regression.py
import boto3
import statistics
from datetime import datetime, timedelta

cloudwatch = boto3.client('cloudwatch')

def get_response_times(hours=24):
    """Get response time metrics for the last N hours"""
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(hours=hours)

    response = cloudwatch.get_metric_statistics(
        Namespace='AWS/ApiGateway',
        MetricName='Latency',
        Dimensions=[
            {
                'Name': 'ApiName',
                'Value': 'agent-runtime-api'
            }
        ],
        StartTime=start_time,
        EndTime=end_time,
        Period=3600,
        Statistics=['Average', 'p95']
    )

    return response['Datapoints']

def detect_regression(current_p95, baseline_p95, threshold=0.2):
    """Detect if current performance is significantly worse than baseline"""
    degradation = (current_p95 - baseline_p95) / baseline_p95

    if degradation > threshold:
        print(f"🚨 Performance regression detected: {degradation:.1%} degradation")
        return True

    return False

# Usage
datapoints = get_response_times()
current_p95 = statistics.mean([dp['p95'] for dp in datapoints[-1:]])
baseline_p95 = statistics.mean([dp['p95'] for dp in datapoints[:-1]])

if detect_regression(current_p95, baseline_p95):
    # Trigger alert or rollback
    pass
```

## Performance SLAs

### Service Level Objectives

| Metric | Target | Critical Threshold | Warning Threshold |
|--------|--------|-------------------|-------------------|
| API p95 Latency | < 500ms | > 1000ms | > 750ms |
| API Availability | 99.9% | < 99.5% | < 99.8% |
| Error Rate | < 1% | > 5% | > 2% |
| Throughput | 1000 req/min | N/A | 800 req/min |

### Performance Budget

- **CPU Budget**: < 70% average utilization
- **Memory Budget**: < 80% average utilization
- **Network Budget**: < 50% of available bandwidth
- **Database Budget**: < 80% of provisioned capacity

### Alerting Rules

```bash
# Create performance alerts
aws cloudwatch put-metric-alarm \
    --alarm-name "${PROJECT_NAME}-high-latency" \
    --alarm-description "API latency too high" \
    --metric-name Latency \
    --namespace AWS/ApiGateway \
    --statistic p95 \
    --period 300 \
    --threshold 750 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --alarm-actions $SNS_TOPIC_ARN
```

## Future Performance Improvements

### Short Term (1-3 months)

1. **Implement Response Caching**
   - Cache governance decisions
   - Cache static API responses
   - Implement Redis/ElastiCache

2. **Database Query Optimization**
   - Implement query result caching
   - Add database indexes
   - Optimize DynamoDB access patterns

3. **Connection Pooling**
   - Implement HTTP connection pooling
   - Optimize Lambda container reuse
   - Reduce connection overhead

### Medium Term (3-6 months)

1. **API Gateway Integration**
   - Move from ALB to API Gateway
   - Implement request/response transformation
   - Add built-in caching and throttling

2. **Service Mesh Optimization**
   - Implement Istio service mesh
   - Add circuit breakers and retries
   - Implement intelligent routing

3. **Multi-Region Deployment**
   - Implement cross-region replication
   - Add Global Accelerator
   - Implement geo-based routing

### Long Term (6+ months)

1. **GPU Support**
   - Add GPU-enabled ECS tasks
   - Implement ML inference optimization
   - Add model caching and warm-up

2. **Event-Driven Architecture**
   - Implement async processing with SQS/Kinesis
   - Add event sourcing patterns
   - Implement CQRS architecture

3. **Advanced Caching**
   - Implement distributed caching
   - Add edge caching with CloudFront
   - Implement cache invalidation strategies
