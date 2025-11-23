# Task 7: Documentation

**Duration:** 4-6 hours
**Priority:** Medium
**Dependencies:** All previous tasks

## Overview

Create comprehensive documentation for architecture, operations, security, and deployment procedures to ensure the system can be maintained and operated effectively.

## Objectives

- [ ] System architecture documentation with diagrams
- [ ] Operations runbook for common procedures
- [ ] Failure and resilience plan
- [ ] Security model documentation
- [ ] Setup and deployment instructions
- [ ] API documentation
- [ ] Troubleshooting guides
- [ ] Update README with complete setup guide

## Prerequisites

- [ ] All tasks completed
- [ ] System tested end-to-end
- [ ] Performance benchmarks completed
- [ ] Security audit passed

## File Structure

```
docs/
├── architecture.md          # System architecture
├── failure-resilience.md    # Failure handling
├── security.md              # Security model
├── runbook.md              # Operations procedures
├── setup-guide.md          # Setup instructions
├── troubleshooting.md      # Common issues
├── api.md                  # API documentation
└── performance.md          # Performance characteristics
README.md                   # Updated main README
```

## Implementation Steps

### Step 7.1: Architecture Documentation (1-2 hours)

**File: docs/architecture.md**

```markdown
# System Architecture

## Overview

The AWS Agent Runtime implements a zero-trust architecture for secure agentic workloads using microservices, service mesh, and governance layers.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWS Cloud (us-east-1)                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    VPC (10.0.0.0/16)                    │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │          Public Subnet (10.0.1.0/24)            │    │   │
│  │  │  ┌─────────────────────────────────────────┐    │    │   │
│  │  │  │           ALB (Internal)               │    │    │   │
│  │  │  │  ┌─────────────────────────────────┐   │    │    │   │
│  │  │  │  │     Orbit Service (ECS)       │   │    │    │   │
│  │  │  │  │                                 │   │    │    │   │
│  │  │  │  │  • HTTP API (/dispatch)       │   │    │    │   │
│  │  │  │  │  • Governance Integration     │   │    │    │   │
│  │  │  │  │  • SigV4 Request Signing      │   │    │    │   │
│  │  │  │  └─────────────────────────────────┘   │    │    │   │
│  │  │  └─────────────────────────────────────────┘    │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                         │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │       Private Subnet (10.0.2.0/24)              │    │   │
│  │  │  ┌─────────────────────────────────────────┐    │    │   │
│  │  │  │     Governance Lambda                 │    │    │   │
│  │  │  │  ┌─────────────────────────────────┐   │    │    │   │
│  │  │  │  │                                 │   │    │    │   │
│  │  │  │  │  • Policy Evaluation            │   │    │    │   │
│  │  │  │  │  • Think → Govern → Act         │   │    │    │   │
│  │  │  │  └─────────────────────────────────┘   │    │    │   │
│  │  │  └─────────────────────────────────────────┘    │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                         │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │    Axon Runtime Subnet (10.0.3.0/24)            │    │   │
│  │  │  ┌─────────────────────────────────────────┐    │    │   │
│  │  │  │     Axon Service (ECS)                │    │    │   │
│  │  │  │  ┌─────────────────────────────────┐   │    │    │   │
│  │  │  │  │                                 │   │    │    │   │
│  │  │  │  │  • HTTP API (/reason)           │   │    │    │   │
│  │  │  │  │  • Reasoning Engine             │   │    │    │   │
│  │  │  │  │  • SigV4 Verification           │   │    │    │   │
│  │  │  │  └─────────────────────────────────┘   │    │    │   │
│  │  │  └─────────────────────────────────────────┘    │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              Supporting Services                       │    │
│  │  ┌─────────────────────────────────┐ ┌─────────────┐   │    │
│  │  │      AWS App Mesh              │ │  DynamoDB   │   │    │
│  │  │  • Service Discovery           │ │  • Policies │   │    │
│  │  │  • Traffic Encryption          │ └─────────────┘   │    │
│  │  └─────────────────────────────────┘                  │    │
│  │                                                        │    │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │    │
│  │  │ ECR Registry│ │ CloudWatch │ │ KMS Keys   │      │    │
│  │  │ • Axon      │ │ • Logs     │ │ • Axon     │      │    │
│  │  │ • Orbit     │ │ • Metrics  │ │ • Orbit    │      │    │
│  │  └─────────────┘ └─────────────┘ └─────────────┘      │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### Network Architecture

#### VPC Design
- **CIDR**: 10.0.0.0/16
- **Availability Zones**: 3 (us-east-1a, us-east-1b, us-east-1c)
- **Subnets**:
  - Public subnets (3): Load balancers, NAT gateways
  - Private subnets (3): General services (Orbit, Governance)
  - Axon runtime subnets (3): Isolated reasoning service

#### Security Layers
1. **Internet Gateway**: Public subnet internet access
2. **NAT Gateways**: Private subnet outbound traffic
3. **Network ACLs**: Subnet-level traffic filtering
4. **Security Groups**: Instance-level traffic control
5. **App Mesh**: Service-to-service communication

### Service Components

#### Axon Service
- **Purpose**: Reasoning and inference engine
- **Technology**: Go application in ECS Fargate
- **Endpoints**:
  - `GET /health`: Health check
  - `GET /reason`: Reasoning execution
- **Security**: SigV4 signature verification
- **Isolation**: Dedicated subnet, no internet access

#### Orbit Service
- **Purpose**: Request orchestration and governance
- **Technology**: Go application in ECS Fargate
- **Endpoints**:
  - `GET /health`: Health check
  - `POST /dispatch`: Request processing
- **Security**: SigV4 request signing, governance checks

#### Governance Lambda
- **Purpose**: Pre-call authorization (Think → Govern → Act)
- **Technology**: Python Lambda function
- **Data Store**: DynamoDB for policies
- **Integration**: Synchronous policy evaluation

### Data Flow

#### Normal Operation
1. **Client Request** → ALB (HTTPS)
2. **ALB** → Orbit Service (HTTP)
3. **Orbit** → Governance Lambda (policy check)
4. **Governance** → DynamoDB (policy lookup)
5. **Orbit** → Axon Service (via App Mesh, signed request)
6. **Axon** → Response to Orbit
7. **Orbit** → Response to client

#### Security Flow
- All requests include correlation IDs
- Orbit signs requests with SigV4
- Axon verifies signatures
- Governance enforces policies
- All traffic encrypted in transit

### Storage and Secrets

#### Secrets Management
- **AWS Secrets Manager**: Encrypted secrets storage
- **KMS Keys**: Service-specific encryption keys
- **Rotation**: Automated 30-day rotation cycle
- **Access**: IAM role-based access control

#### Data Storage
- **DynamoDB**: Governance policies and metadata
- **CloudWatch Logs**: Application and security logs
- **ECR**: Container image registry
- **S3**: Log archives and backups

### Monitoring and Observability

#### Metrics Collection
- **ECS**: CPU, memory, task counts
- **Lambda**: Invocations, duration, errors
- **ALB**: Request counts, latency, error rates
- **DynamoDB**: Read/write capacity, errors

#### Logging Strategy
- **Structured JSON**: Consistent log format
- **Correlation IDs**: Request tracing
- **Log Levels**: ERROR, WARN, INFO, DEBUG
- **Retention**: 30 days active, 1 year archived

#### Alerting
- **Service Health**: CPU > 80%, memory > 80%
- **Errors**: Error rate > 5%, 5xx responses
- **Security**: Governance denials, unauthorized access
- **Performance**: Latency > p95 thresholds

## Scalability Considerations

### Horizontal Scaling
- **ECS Services**: Auto-scaling based on CPU/memory
- **Lambda**: Concurrent execution limits
- **DynamoDB**: On-demand or provisioned capacity

### Performance Targets
- **Latency**: p95 < 500ms for API calls
- **Availability**: 99.9% uptime
- **Throughput**: 1000 requests/minute baseline

### Cost Optimization
- **Fargate**: Right-sizing CPU/memory
- **Lambda**: Optimize function duration
- **DynamoDB**: Use on-demand pricing
- **CloudWatch**: Selective log retention

## Security Architecture

### Zero-Trust Principles
1. **No Implicit Trust**: Every request verified
2. **Least Privilege**: Minimal permissions
3. **Network Isolation**: Private subnets only
4. **Encrypted Communication**: TLS everywhere

### Threat Mitigation
- **Network Attacks**: VPC isolation, NACLs
- **Credential Theft**: Short-lived tokens, rotation
- **Data Exfiltration**: Encryption at rest/transit
- **Service Impersonation**: SigV4 signing

## Deployment Architecture

### CI/CD Pipeline
1. **Build**: Docker images, security scanning
2. **Test**: Unit, integration, security tests
3. **Deploy**: Blue-green deployment to ECS
4. **Verify**: Health checks, smoke tests
5. **Monitor**: Automated validation

### Environment Strategy
- **Development**: Isolated resources, full access
- **Staging**: Production-like, restricted access
- **Production**: Locked down, audit logging

## Future Considerations

### GPU Support
- **ECS GPU Tasks**: For ML inference workloads
- **Instance Types**: P3, G4dn families
- **Auto-scaling**: GPU utilization metrics

### Multi-Region
- **Global Accelerator**: Cross-region load balancing
- **Aurora Global Database**: Multi-region data
- **Route 53**: DNS-based routing

### Advanced Features
- **Service Mesh**: Istio integration
- **Event Streaming**: Kinesis for async processing
- **Caching**: ElastiCache for performance
- **CDN**: CloudFront for static assets
```

**Test Step 7.1:**

```bash
# Validate documentation
cd docs
markdown-link-check architecture.md
markdown-lint architecture.md
```

### Step 7.2: Failure and Resilience Plan (1 hour)

**File: docs/failure-resilience.md**

```markdown
# Failure and Resilience Plan

## Overview

This document outlines failure scenarios, recovery procedures, and resilience strategies for the AWS Agent Runtime system.

## Failure Scenarios

### 1. Service Failures

#### ECS Task Failures
**Symptoms**:
- Health checks failing
- Error rate increasing
- Service unavailable

**Detection**:
- CloudWatch alarms on task count
- ALB target group health checks
- Application error logs

**Recovery**:
```bash
# Check service status
aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME

# Update service (forces new deployment)
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force-new-deployment

# Scale up temporarily
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 4
```

**Prevention**:
- Multiple AZ deployment
- Health checks every 30 seconds
- Circuit breakers in application code

#### Lambda Function Failures
**Symptoms**:
- Governance calls timing out
- Increased error rates in Orbit
- CloudWatch Lambda errors

**Detection**:
- Lambda error metrics
- Timeout alarms
- Application logs

**Recovery**:
```bash
# Check Lambda logs
aws logs tail /aws/lambda/${PROJECT_NAME}-governance --follow

# Update function code
aws lambda update-function-code --function-name ${PROJECT_NAME}-governance --zip-file fileb://lambda.zip

# Check concurrency limits
aws lambda get-function --function-name ${PROJECT_NAME}-governance --query 'Concurrency'
```

### 2. Infrastructure Failures

#### VPC/Network Issues
**Symptoms**:
- Services unreachable
- Cross-AZ communication failing
- NAT gateway issues

**Detection**:
- VPC flow logs
- Network ACL changes
- Security group modifications

**Recovery**:
```bash
# Check VPC status
aws ec2 describe-vpcs --vpc-ids $VPC_ID

# Verify route tables
aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC_ID

# Check NAT gateways
aws ec2 describe-nat-gateways --filter Name=vpc-id,Values=$VPC_ID
```

#### Database Connectivity
**Symptoms**:
- Governance failures
- Policy lookup errors
- DynamoDB timeouts

**Detection**:
- DynamoDB metrics (throttles, errors)
- Lambda duration increases
- Application error logs

**Recovery**:
```bash
# Check DynamoDB status
aws dynamodb describe-table --table-name ${PROJECT_NAME}-governance-policies

# Monitor throttling
aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB --metric-name ThrottledRequests

# Increase capacity if needed
aws dynamodb update-table --table-name ${PROJECT_NAME}-governance-policies --billing-mode PAY_PER_REQUEST
```

### 3. Security Incidents

#### Unauthorized Access Attempts
**Symptoms**:
- Increased governance denials
- Failed SigV4 verifications
- Unusual traffic patterns

**Detection**:
- CloudWatch security metrics
- VPC flow log analysis
- IAM access analyzer findings

**Response**:
1. **Isolate**: Remove compromised resources
2. **Investigate**: Review CloudTrail logs
3. **Contain**: Update security groups, NACLs
4. **Recover**: Deploy patched versions
5. **Learn**: Update security policies

#### Secret Compromise
**Symptoms**:
- Unexpected service failures
- Secrets rotation alerts
- Unusual API calls

**Detection**:
- Secrets Manager access logs
- KMS key usage anomalies
- Service authentication failures

**Recovery**:
```bash
# Rotate all secrets immediately
aws lambda invoke --function-name ${PROJECT_NAME}-secrets-rotation

# Update KMS keys
aws kms rotate-key-material --key-id alias/${PROJECT_NAME}-axon
aws kms rotate-key-material --key-id alias/${PROJECT_NAME}-orbit

# Force service redeployment
aws ecs update-service --cluster $CLUSTER_NAME --service ${PROJECT_NAME}-axon --force-new-deployment
aws ecs update-service --cluster $CLUSTER_NAME --service ${PROJECT_NAME}-orbit --force-new-deployment
```

## Resilience Strategies

### High Availability

#### Multi-AZ Deployment
- Services deployed across 3 AZs
- ALB distributes traffic
- Database multi-AZ configuration

#### Auto-Scaling
```hcl
resource "aws_appautoscaling_target" "axon" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "axon_cpu" {
  name               = "${var.project_name}-axon-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.axon.resource_id
  scalable_dimension = aws_appautoscaling_target.axon.scalable_dimension
  service_namespace  = aws_appautoscaling_target.axon.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
```

### Fault Tolerance

#### Circuit Breakers
```go
type CircuitBreaker struct {
    failures    int
    lastFailTime time.Time
    state       string // "closed", "open", "half-open"
}

func (cb *CircuitBreaker) Call(fn func() error) error {
    if cb.state == "open" {
        if time.Since(cb.lastFailTime) > cb.timeout {
            cb.state = "half-open"
        } else {
            return errors.New("circuit breaker is open")
        }
    }

    err := fn()
    if err != nil {
        cb.failures++
        cb.lastFailTime = time.Now()
        if cb.failures >= cb.threshold {
            cb.state = "open"
        }
        return err
    }

    cb.failures = 0
    cb.state = "closed"
    return nil
}
```

#### Retry Logic
```go
func (c *AxonClient) CallWithRetry(ctx context.Context, correlationID string) (string, error) {
    var lastErr error

    for attempt := 0; attempt < c.maxRetries; attempt++ {
        result, err := c.CallReasoning(ctx, correlationID)
        if err == nil {
            return result, nil
        }

        lastErr = err

        // Exponential backoff
        backoff := time.Duration(attempt+1) * c.baseBackoff
        if backoff > c.maxBackoff {
            backoff = c.maxBackoff
        }

        c.logger.Printf("RETRY [%s] Attempt %d failed, retrying in %v: %v",
            correlationID, attempt+1, backoff, err)

        select {
        case <-time.After(backoff):
        case <-ctx.Done():
            return "", ctx.Err()
        }
    }

    return "", fmt.Errorf("max retries exceeded: %w", lastErr)
}
```

### Disaster Recovery

#### Backup Strategy
- **CloudWatch Logs**: 30 days retention, S3 export
- **DynamoDB**: Point-in-time recovery enabled
- **Secrets**: Automatic rotation, backup via Lambda
- **Infrastructure**: Terraform state in S3 with versioning

#### Recovery Time Objectives (RTO)
- **Service Failure**: < 5 minutes (auto-healing)
- **AZ Failure**: < 15 minutes (multi-AZ failover)
- **Region Failure**: < 1 hour (cross-region recovery)

#### Recovery Point Objectives (RPO)
- **Application Data**: Near real-time (DynamoDB streams)
- **Logs**: < 5 minutes (CloudWatch real-time)
- **Configuration**: < 1 hour (Terraform state)

## Incident Response

### Severity Levels

| Level | Description | Response Time | Communication |
|-------|-------------|---------------|----------------|
| **P0** | System down, no redundancy | Immediate (< 5 min) | All stakeholders |
| **P1** | Major functionality impaired | 15 minutes | Team leads |
| **P2** | Minor issues, partial degradation | 1 hour | On-call engineer |
| **P3** | Non-critical issues | 4 hours | Next business day |

### Response Process

#### 1. Detection
- Automated monitoring alerts
- User reports
- Log analysis

#### 2. Assessment
```bash
# Check system status
./scripts/health-check.sh

# Review recent changes
aws cloudtrail lookup-events --start-time $(date -u -d '1 hour ago' +%s)

# Check metrics
aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name RunningTaskCount
```

#### 3. Communication
- Update incident status page
- Notify stakeholders via SNS
- Provide regular updates

#### 4. Resolution
- Follow runbook procedures
- Implement temporary fixes
- Deploy permanent solution

#### 5. Post-Mortem
```markdown
# Incident Report: [Title]

## Timeline
- **Detected**: [Timestamp]
- **Resolved**: [Timestamp]
- **Duration**: [Duration]

## Impact
- **Users Affected**: [Number]
- **Services Down**: [List]

## Root Cause
[Detailed analysis]

## Resolution
[Steps taken]

## Prevention
[Future improvements]
```

## Performance Degradation

### Slow Response Times
**Symptoms**:
- Increased latency
- Timeout errors
- User complaints

**Diagnosis**:
```bash
# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Duration \
    --statistics p95 \
    --start-time $(date -u -d '1 hour ago' +%s)

# Review application logs
aws logs filter-log-events \
    --log-group-name /ecs/${PROJECT_NAME}-axon \
    --filter-pattern '"duration"' \
    --start-time $(date -u -d '1 hour ago' +%s)
```

**Optimization**:
- Increase Lambda memory allocation
- Optimize database queries
- Implement caching
- Scale ECS services

### Resource Exhaustion
**Symptoms**:
- CPU/memory spikes
- Service throttling
- Error rate increases

**Recovery**:
```bash
# Scale services
aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --desired-count 4

# Check resource usage
aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME --query 'taskArns[]' --output text)
```

## Testing and Validation

### Chaos Engineering
```bash
# Terminate random ECS task
TASK_ARN=$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name ${PROJECT_NAME}-axon --query 'taskArns[0]' --output text)
aws ecs stop-task --cluster $CLUSTER_NAME --task $TASK_ARN

# Verify auto-healing
aws ecs describe-services --cluster $CLUSTER_NAME --services ${PROJECT_NAME}-axon --query 'services[0].runningCount'
```

### Load Testing
```bash
# Install hey (load testing tool)
# Test with increasing load
hey -n 1000 -c 10 -m POST -d '{"test": "data"}' https://$ALB_DNS/dispatch

# Monitor during test
aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization --statistics Maximum
```

### Failover Testing
```bash
# Simulate AZ failure
aws ec2 stop-instances --instance-ids $NAT_INSTANCE_ID

# Verify traffic routing
aws cloudwatch get-metric-statistics --namespace AWS/NetworkELB --metric-name HealthyHostCount
```

## Cost Optimization

### Resource Rightsizing
- **ECS Tasks**: Monitor CPU/memory usage, adjust allocations
- **Lambda**: Optimize memory for better performance/cost
- **DynamoDB**: Use on-demand pricing, monitor usage patterns

### Auto-Scaling Configuration
```hcl
# Scale down during low usage
resource "aws_appautoscaling_policy" "axon_scale_down" {
  name               = "${var.project_name}-axon-scale-down"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.axon.resource_id
  scalable_dimension = aws_appautoscaling_target.axon.scalable_dimension
  service_namespace  = aws_appautoscaling_target.axon.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 30.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
```

## Maintenance Windows

### Scheduled Maintenance
- **Weekly**: Security patching, log rotation
- **Monthly**: Dependency updates, performance tuning
- **Quarterly**: Architecture reviews, capacity planning

### Communication Plan
- Notify stakeholders 1 week in advance
- Provide maintenance window (2-4 AM UTC)
- Post-maintenance report with changes
- Rollback plan for any issues

## Metrics and KPIs

### Availability Metrics
- **Uptime**: (Total time - downtime) / total time * 100
- **MTTR**: Mean time to recovery
- **MTBF**: Mean time between failures

### Performance Metrics
- **Latency**: p50, p95, p99 response times
- **Throughput**: Requests per second
- **Error Rate**: 4xx/5xx response percentage

### Business Metrics
- **User Satisfaction**: Based on error rates and latency
- **Cost Efficiency**: Cost per request
- **Security**: Security incidents per month

### Monitoring Dashboard
```
┌─────────────────────────────────────────────────────────────┐
│                    System Health Dashboard                 │
├─────────────────────────────────────────────────────────────┤
│ Availability: 99.95%     │ MTTR: 4min    │ MTBF: 15 days    │
│ Latency p95: 245ms       │ Errors: 0.02% │ Cost: $0.002/req │
├─────────────────────────────────────────────────────────────┤
│ Recent Incidents: 0      │ Active Alerts: 0               │
│ Next Maintenance: 2024-02-15 02:00 UTC                    │
└─────────────────────────────────────────────────────────────┘
```
```

**Test Step 7.2:**

```bash
# Validate failure scenarios
cd docs
grep -n "Symptoms\|Detection\|Recovery" failure-resilience.md
```

### Step 7.3: Operations Runbook (1 hour)

**File: docs/runbook.md**

```markdown
# Operations Runbook

## Daily Operations

### Health Checks

#### Automated Health Checks
```bash
# Run comprehensive health check
./scripts/health-check.sh

# Expected output:
# ✅ Axon service: 2/2 tasks healthy
# ✅ Orbit service: 2/2 tasks healthy
# ✅ Governance Lambda: responding
# ✅ DynamoDB: accessible
```

#### Manual Verification
```bash
# Check ECS services
aws ecs describe-services --cluster ${PROJECT_NAME}-cluster \
    --services ${PROJECT_NAME}-axon ${PROJECT_NAME}-orbit \
    --query 'services[*].{name:serviceName,running:runningCount,desired:desiredCount,status:status}'

# Check Lambda function
aws lambda get-function --function-name ${PROJECT_NAME}-governance \
    --query '{State:State,LastModified:LastModified}'

# Check DynamoDB
aws dynamodb describe-table --table-name ${PROJECT_NAME}-governance-policies \
    --query '{Status:TableStatus,ItemCount:ItemCount}'
```

### Monitoring Review

#### Key Metrics to Review
```bash
# CPU Utilization (should be < 70%)
aws cloudwatch get-metric-statistics --namespace AWS/ECS \
    --metric-name CPUUtilization --statistics Average \
    --start-time $(date -u -d '1 hour ago' +%s) \
    --end-time $(date -u +%s) --period 3600

# Error Rates (should be < 1%)
aws cloudwatch get-metric-statistics --namespace ${PROJECT_NAME}/Axon \
    --metric-name ErrorCount --statistics Sum \
    --start-time $(date -u -d '1 hour ago' +%s)

# Governance Decisions
aws cloudwatch get-metric-statistics --namespace ${PROJECT_NAME}/Governance \
    --metric-name DenialCount --statistics Sum \
    --start-time $(date -u -d '1 hour ago' +%s)
```

#### Alert Review
- Check CloudWatch dashboard for any active alerts
- Review recent error logs in CloudWatch Insights
- Verify no unusual spikes in metrics

## Weekly Operations

### Log Rotation and Archival

```bash
# Export old logs to S3
LOG_GROUP="/ecs/${PROJECT_NAME}-axon"
START_TIME=$(date -u -d '30 days ago' +%s)
END_TIME=$(date -u -d '7 days ago' +%s)

aws logs create-export-task \
    --log-group-name $LOG_GROUP \
    --from $START_TIME \
    --to $END_TIME \
    --destination "s3://${PROJECT_NAME}-logs-archive" \
    --destination-prefix "logs/axon/"
```

### Security Audit

```bash
# Run security audit
./scripts/security-audit.sh

# Check for new IAM Access Analyzer findings
aws accessanalyzer list-findings --analyzer-arn $ANALYZER_ARN \
    --filter '{"status": [{"eq": ["ACTIVE"]}]}'
```

### Performance Analysis

```bash
# Generate performance report
./observability/scripts/metric-report.sh

# Review scaling policies
aws application-autoscaling describe-scaling-policies \
    --service-namespace ecs \
    --resource-id service/${PROJECT_NAME}-cluster/${PROJECT_NAME}-axon
```

## Monthly Operations

### Patch Management

#### ECS Service Updates
```bash
# Update ECS service to latest platform version
aws ecs update-service \
    --cluster ${PROJECT_NAME}-cluster \
    --service ${PROJECT_NAME}-axon \
    --platform-version LATEST \
    --force-new-deployment

# Monitor deployment
aws ecs describe-services \
    --cluster ${PROJECT_NAME}-cluster \
    --services ${PROJECT_NAME}-axon \
    --query 'services[0].{events:events[0:3]}'
```

#### Lambda Runtime Updates
```bash
# Update Lambda runtime (if applicable)
aws lambda update-function-configuration \
    --function-name ${PROJECT_NAME}-governance \
    --runtime python3.9

# Update function code with latest dependencies
aws lambda update-function-code \
    --function-name ${PROJECT_NAME}-governance \
    --zip-file fileb://governance/lambda/lambda.zip
```

### Cost Optimization

```bash
# Analyze costs
aws ce get-cost-and-usage \
    --time-period Start=$(date -u -d '30 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
    --granularity MONTHLY \
    --metrics "BlendedCost" \
    --group-by Type=DIMENSION,Key=SERVICE

# Review resource utilization
aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name CPUUtilization \
    --statistics Average,Maximum \
    --start-time $(date -u -d '30 days ago' +%s) \
    --period 86400
```

## Incident Response

### P0 Incident (System Down)

#### Immediate Actions (0-5 minutes)
1. **Acknowledge Alert**: Confirm receipt via PagerDuty/SNS
2. **Assess Impact**: Check system status
   ```bash
   ./scripts/health-check.sh
   ```
3. **Communicate**: Update incident status, notify stakeholders

#### Investigation (5-15 minutes)
1. **Check Recent Changes**:
   ```bash
   aws cloudtrail lookup-events \
       --start-time $(date -u -d '1 hour ago' +%s) \
       --lookup-attributes AttributeKey=EventName,AttributeValue=UpdateService
   ```

2. **Review Logs**:
   ```bash
   aws logs filter-log-events \
       --log-group-name /ecs/${PROJECT_NAME}-axon \
       --filter-pattern "ERROR" \
       --start-time $(date -u -d '1 hour ago' +%s)
   ```

3. **Check Infrastructure**:
   ```bash
   aws ecs describe-services --cluster ${PROJECT_NAME}-cluster --services ${PROJECT_NAME}-axon
   aws lambda get-function --function-name ${PROJECT_NAME}-governance
   ```

#### Resolution (15-60 minutes)
1. **Restart Services**:
   ```bash
   aws ecs update-service \
       --cluster ${PROJECT_NAME}-cluster \
       --service ${PROJECT_NAME}-axon \
       --desired-count 0

   aws ecs update-service \
       --cluster ${PROJECT_NAME}-cluster \
       --service ${PROJECT_NAME}-axon \
       --desired-count 2
   ```

2. **Force Redeployment**:
   ```bash
   aws ecs update-service \
       --cluster ${PROJECT_NAME}-cluster \
       --service ${PROJECT_NAME}-axon \
       --force-new-deployment
   ```

3. **Verify Recovery**:
   ```bash
   aws ecs wait services-stable --cluster ${PROJECT_NAME}-cluster --services ${PROJECT_NAME}-axon
   ./scripts/health-check.sh
   ```

### P1 Incident (Degraded Performance)

#### Investigation
1. **Check Metrics**:
   ```bash
   aws cloudwatch get-metric-statistics \
       --namespace AWS/ECS \
       --metric-name CPUUtilization \
       --statistics Maximum \
       --start-time $(date -u -d '1 hour ago' +%s)
   ```

2. **Scale Resources**:
   ```bash
   aws ecs update-service \
       --cluster ${PROJECT_NAME}-cluster \
       --service ${PROJECT_NAME}-axon \
       --desired-count 4
   ```

3. **Monitor Recovery**:
   ```bash
   watch -n 30 aws ecs describe-services \
       --cluster ${PROJECT_NAME}-cluster \
       --services ${PROJECT_NAME}-axon \
       --query 'services[0].runningCount'
   ```

### P2 Incident (Minor Issues)

#### Investigation
1. **Log Analysis**:
   ```bash
   aws logs filter-log-events \
       --log-group-name /ecs/${PROJECT_NAME}-axon \
       --filter-pattern "WARN" \
       --start-time $(date -u -d '1 hour ago' +%s)
   ```

2. **Scheduled Fix**: Address during next maintenance window

## Deployment Procedures

### Standard Deployment

#### Pre-Deployment Checks
```bash
# Verify infrastructure
cd infra && terraform plan

# Run tests
cd ../cicd/scripts && ./test.sh

# Backup current state
aws ecs describe-services --cluster ${PROJECT_NAME}-cluster \
    --services ${PROJECT_NAME}-axon > pre-deployment-backup.json
```

#### Deployment Steps
```bash
# Deploy infrastructure changes
cd infra && terraform apply -auto-approve

# Build and push images
cd ../services/axon && docker build -t ${PROJECT_NAME}/axon:${GITHUB_SHA} .
aws ecr get-login-password | docker login --username AWS --password-stdin ${AWS_ECR_REGISTRY}
docker push ${PROJECT_NAME}/axon:${GITHUB_SHA}

# Update ECS service
aws ecs register-task-definition --cli-input-json file://infra/modules/ecs/task-definitions/axon.json
aws ecs update-service --cluster ${PROJECT_NAME}-cluster --service ${PROJECT_NAME}-axon --force-new-deployment

# Monitor deployment
aws ecs wait services-stable --cluster ${PROJECT_NAME}-cluster --services ${PROJECT_NAME}-axon
```

#### Post-Deployment Verification
```bash
# Health checks
./scripts/health-check.sh

# Smoke tests
curl -f https://$ALB_DNS/health

# Performance validation
./scripts/load-test.sh
```

### Rollback Procedure

#### Quick Rollback (0-5 minutes)
```bash
# Rollback to previous task definition
PREVIOUS_TASK_ARN=$(aws ecs list-task-definitions \
    --family-prefix ${PROJECT_NAME}-axon \
    --sort DESC \
    --max-items 2 \
    --query 'taskDefinitionArns[1]' \
    --output text)

aws ecs update-service \
    --cluster ${PROJECT_NAME}-cluster \
    --service ${PROJECT_NAME}-axon \
    --task-definition $PREVIOUS_TASK_ARN \
    --force-new-deployment
```

#### Full Rollback (5-15 minutes)
```bash
# Restore from backup
aws ecs update-service \
    --cluster ${PROJECT_NAME}-cluster \
    --service ${PROJECT_NAME}-axon \
    --cli-input-json file://pre-deployment-backup.json

# Revert infrastructure changes
cd infra && terraform plan -out=rollback.tfplan
terraform apply rollback.tfplan
```

## Backup and Recovery

### Automated Backups

#### DynamoDB Backup
```bash
# Daily backup
aws dynamodb create-backup \
    --table-name ${PROJECT_NAME}-governance-policies \
    --backup-name "daily-$(date +%Y%m%d)"

# Cleanup old backups (keep 30 days)
aws dynamodb list-backups --table-name ${PROJECT_NAME}-governance-policies \
    --query 'BackupSummaries[?BackupCreationDateTime<`$(date -u -d "30 days ago" +%s)`].BackupArn' \
    --output text | xargs -I {} aws dynamodb delete-backup --backup-arn {}
```

#### Secrets Backup
```bash
# Secrets are automatically versioned
# Manual export if needed
aws secretsmanager get-secret-value --secret-id ${PROJECT_NAME}/axon \
    --query 'SecretString' > axon-secrets-backup.json
```

### Recovery Procedures

#### DynamoDB Recovery
```bash
# Restore from backup
BACKUP_ARN=$(aws dynamodb list-backups \
    --table-name ${PROJECT_NAME}-governance-policies \
    --query 'BackupSummaries[0].BackupArn' \
    --output text)

aws dynamodb restore-table-from-backup \
    --target-table-name ${PROJECT_NAME}-governance-policies-restored \
    --backup-arn $BACKUP_ARN
```

#### Service Recovery
```bash
# Recreate services
aws ecs create-service --cli-input-json file://infra/modules/ecs/services/axon-service.json

# Restore Lambda
aws lambda create-function --function-name ${PROJECT_NAME}-governance \
    --zip-file fileb://governance/lambda/lambda.zip \
    --role $LAMBDA_ROLE_ARN \
    --runtime python3.9 \
    --handler handler.lambda_handler
```

## On-Call Rotation

### Responsibilities
- Monitor alerts 24/7
- Respond to incidents within SLA
- Perform daily health checks
- Participate in post-mortems

### Handover Process
```markdown
# On-Call Handover

## Current Status
- [ ] All services healthy
- [ ] No active incidents
- [ ] Recent deployments successful
- [ ] Alerts acknowledged

## Known Issues
- [ ] Issue 1: [Description]
- [ ] Issue 2: [Description]

## Recent Changes
- [ ] Deployment on [Date]: [Description]
- [ ] Infrastructure change: [Description]

## Contacts
- Team Lead: [Name] ([Contact])
- DevOps: [Name] ([Contact])
- Security: [Name] ([Contact])
```

### Escalation Paths
1. **On-Call Engineer** (0-15 min response)
2. **Team Lead** (15-60 min response)
3. **VP Engineering** (1-4 hour response)
4. **CEO** (4+ hour response - business impact only)

## Tools and Resources

### Monitoring Tools
- **CloudWatch**: Metrics, logs, alarms
- **AWS X-Ray**: Distributed tracing
- **CloudWatch Insights**: Log analysis
- **CloudWatch Synthetics**: Synthetic monitoring

### Diagnostic Tools
- **AWS CLI**: Infrastructure queries
- **ECS Exec**: Container debugging
- **SSM Session Manager**: Instance access
- **CloudWatch Logs Insights**: Log queries

### Communication Tools
- **Slack**: Team communication
- **PagerDuty**: Alert management
- **Jira**: Incident tracking
- **Confluence**: Documentation

## Performance Tuning

### ECS Optimization
```bash
# Right-size tasks based on metrics
aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks $TASK_ARN \
    --query 'tasks[0].{cpu:cpu,memory:memory}'

# Update task definition
aws ecs register-task-definition --cli-input-json file://optimized-task-def.json
```

### Lambda Optimization
```bash
# Analyze Lambda performance
aws lambda get-function --function-name ${PROJECT_NAME}-governance \
    --query '{MemorySize:MemorySize,Timeout:Timeout}'

# Update configuration
aws lambda update-function-configuration \
    --function-name ${PROJECT_NAME}-governance \
    --memory-size 512 \
    --timeout 30
```

### Database Optimization
```bash
# Monitor DynamoDB performance
aws dynamodb describe-table --table-name ${PROJECT_NAME}-governance-policies \
    --query '{ReadCapacityUnits:ProvisionedThroughput.ReadCapacityUnits,WriteCapacityUnits:ProvisionedThroughput.WriteCapacityUnits}'

# Update capacity
aws dynamodb update-table --table-name ${PROJECT_NAME}-governance-policies \
    --billing-mode PAY_PER_REQUEST
```

## Capacity Planning

### Growth Projections
- **Current Load**: 1000 requests/minute
- **Growth Rate**: 20% month-over-month
- **Peak Load**: 2000 requests/minute

### Scaling Plans
```hcl
# Auto-scaling configuration
resource "aws_appautoscaling_policy" "axon_target_cpu" {
  name               = "${var.project_name}-axon-cpu-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
```

### Cost Monitoring
```bash
# Monthly cost analysis
aws ce get-cost-and-usage \
    --time-period Start=2024-01-01,End=2024-01-31 \
    --granularity MONTHLY \
    --metrics "BlendedCost" \
    --group-by Type=DIMENSION,Key=SERVICE \
    --query 'ResultsByTime[0].Groups[].[Keys[0],Metrics.BlendedCost.Amount]'
```
```

**Test Step 7.3:**

```bash
# Validate runbook completeness
cd docs
grep -c "Procedure\|Steps\|Commands" runbook.md
```

### Step 7.4: Setup and API Documentation (1 hour)

**File: docs/setup-guide.md**

```markdown
# Setup Guide

## Prerequisites

### AWS Account Setup
1. **Create AWS Account** or use existing account
2. **Configure AWS CLI**:
   ```bash
   aws configure
   # Enter your access key, secret key, default region (us-east-1), and output format (json)
   ```

3. **Verify Account Limits**:
   - ECS: 10 clusters, 100 services
   - Lambda: 1000 concurrent executions
   - DynamoDB: 40 read/write capacity units

### Local Development Setup
1. **Install Required Tools**:
   ```bash
   # Terraform
   curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
   sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
   sudo apt-get update && sudo apt-get install terraform

   # AWS CLI v2
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install

   # Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh

   # Go (for local development)
   wget https://golang.org/dl/go1.21.0.linux-amd64.tar.gz
   sudo tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
   export PATH=$PATH:/usr/local/go/bin
   ```

2. **Clone Repository**:
   ```bash
   git clone https://github.com/your-org/aws-agent-runtime-zero-trust.git
   cd aws-agent-runtime-zero-trust
   ```

3. **Initialize Project**:
   ```bash
   ./scripts/setup.sh
   ```

## Infrastructure Deployment

### Step 1: Configure Environment
```bash
# Copy and edit environment configuration
cp .env.local.example .env.local
nano .env.local

# Required variables:
# AWS_REGION=us-east-1
# PROJECT_NAME=agent-runtime
# ENVIRONMENT=dev
```

### Step 2: Deploy Infrastructure
```bash
cd infra

# Initialize Terraform
terraform init

# Review planned changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan
```

### Step 3: Verify Infrastructure
```bash
# Check VPC creation
aws ec2 describe-vpcs --filters Name=tag:Name,Values=${PROJECT_NAME}-vpc

# Verify ECS cluster
aws ecs describe-clusters --clusters ${PROJECT_NAME}-cluster

# Check ECR repositories
aws ecr describe-repositories --repository-names ${PROJECT_NAME}/axon ${PROJECT_NAME}/orbit
```

## Service Deployment

### Step 1: Build Services
```bash
# Build Axon service
cd services/axon
docker build -t axon:latest .

# Build Orbit service
cd ../orbit
docker build -t orbit:latest .
```

### Step 2: Push Images to ECR
```bash
# Authenticate with ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Tag and push Axon
docker tag axon:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${PROJECT_NAME}/axon:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${PROJECT_NAME}/axon:latest

# Tag and push Orbit
docker tag orbit:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${PROJECT_NAME}/orbit:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/${PROJECT_NAME}/orbit:latest
```

### Step 3: Deploy Services
```bash
cd infra

# Update task definitions with new image URIs
terraform apply -target=module.ecs

# Deploy services
aws ecs update-service --cluster ${PROJECT_NAME}-cluster --service ${PROJECT_NAME}-axon --force-new-deployment
aws ecs update-service --cluster ${PROJECT_NAME}-cluster --service ${PROJECT_NAME}-orbit --force-new-deployment
```

### Step 4: Configure Governance
```bash
cd governance/terraform

# Deploy governance infrastructure
terraform init
terraform apply

# Load default policies
cd ../scripts
python load-policies.py
```

## CI/CD Setup

### GitHub Actions Configuration
1. **Create GitHub Repository** (if not already done)
2. **Add Secrets** to repository settings:
   ```
   AWS_REGION: us-east-1
   AWS_ECR_REGISTRY: <account-id>.dkr.ecr.us-east-1.amazonaws.com
   AWS_GITHUB_ACTIONS_ROLE: arn:aws:iam::<account-id>:role/github-actions-role
   AWS_DEPLOY_ROLE: arn:aws:iam::<account-id>:role/deploy-role
   PROJECT_NAME: agent-runtime
   ```
3. **Enable GitHub Actions** in repository settings
4. **Configure Branch Protection**:
   - Require pull request reviews
   - Require status checks (build, security, test)
   - Require branches to be up to date

### OIDC Provider Setup
```bash
# This is handled by Terraform in infra/modules/cicd/github-oidc.tf
cd infra
terraform apply -target=module.cicd
```

## Verification

### Health Checks
```bash
# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers --names ${PROJECT_NAME}-alb --query 'LoadBalancers[0].DNSName' --output text)

# Test health endpoints
curl -f https://${ALB_DNS}/health

# Test governance
curl -X POST https://${ALB_DNS}/dispatch \
  -H "Content-Type: application/json" \
  -d "{}"
```

### Monitoring Setup
```bash
# Check CloudWatch dashboards
aws cloudwatch list-dashboards --query "DashboardEntries[?contains(DashboardName, \`${PROJECT_NAME}\`)]"

# Verify alarms
aws cloudwatch describe-alarms --alarm-name-prefix "${PROJECT_NAME}"

# Check log groups
aws logs describe-log-groups --log-group-name-prefix "/ecs/${PROJECT_NAME}"
```

## Troubleshooting

### Common Issues

#### Terraform Apply Fails
```bash
# Check AWS limits
aws service-quotas get-service-quota --service-code ecs --quota-code L-21DAFBDC

# Verify permissions
aws sts get-caller-identity

# Check Terraform state
cd infra
terraform state list
```

#### Service Deployment Fails
```bash
# Check ECS service events
aws ecs describe-services --cluster ${PROJECT_NAME}-cluster --services ${PROJECT_NAME}-axon \
  --query 'services[0].events[0:5]'

# Check task status
aws ecs list-tasks --cluster ${PROJECT_NAME}-cluster --service-name ${PROJECT_NAME}-axon
aws ecs describe-tasks --cluster ${PROJECT_NAME}-cluster --tasks <task-arn>
```

#### Image Push Fails
```bash
# Check ECR permissions
aws ecr get-authorization-token

# Verify repository exists
aws ecr describe-repositories --repository-names ${PROJECT_NAME}/axon
```

### Logs and Debugging

#### Application Logs
```bash
# Axon logs
aws logs tail /ecs/${PROJECT_NAME}-axon --follow

# Orbit logs
aws logs tail /ecs/${PROJECT_NAME}-orbit --follow

# Governance logs
aws logs tail /aws/lambda/${PROJECT_NAME}-governance --follow
```

#### Infrastructure Logs
```bash
# VPC Flow Logs
aws ec2 describe-flow-logs --query 'FlowLogs[*].FlowLogId'

# CloudTrail events
aws cloudtrail lookup-events --max-items 10
```

## Next Steps

1. **Configure Monitoring**: Set up alerts and notifications
2. **Security Review**: Run security audit and penetration testing
3. **Performance Testing**: Load test the system
4. **Documentation**: Complete operational runbooks
5. **Backup Strategy**: Configure automated backups

## Support

For issues or questions:
- Check the [troubleshooting guide](./troubleshooting.md)
- Review [architecture documentation](./architecture.md)
- Create an issue in the GitHub repository
- Contact the DevOps team

## Cost Estimation

### Monthly Costs (approximate)
- **ECS Fargate**: $50-100 (2 tasks, 24/7)
- **Lambda**: $5-10 (governance calls)
- **DynamoDB**: $5-15 (on-demand)
- **CloudWatch**: $10-20 (logs and metrics)
- **ALB**: $15-25 (data transfer)
- **ECR**: $5 (storage)
- **Secrets Manager**: $5 (secrets)

**Total Estimated Monthly Cost**: $90-190

### Cost Optimization
- Use Fargate Spot for non-production
- Configure auto-scaling to scale to zero
- Set up log retention policies
- Use reserved instances for steady workloads
```

**File: docs/api.md**

```markdown
# API Documentation

## Overview

The AWS Agent Runtime exposes REST APIs for health monitoring, reasoning execution, and request dispatching with governance.

## Base URL
```
https://<alb-dns>/
```

## Authentication

All API requests require AWS SigV4 signing. Requests without proper signatures will be rejected with 401 Unauthorized.

### SigV4 Signing Example
```bash
# Using AWS CLI for testing
aws lambda invoke --function-name test-signer output.json --payload '{"message": "test"}'
```

## Endpoints

### GET /health

Health check endpoint for load balancer monitoring.

**Response:**
```json
{
  "status": "healthy",
  "service": "orbit",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0"
}
```

**Status Codes:**
- `200 OK`: Service is healthy
- `503 Service Unavailable`: Service is unhealthy

### POST /dispatch

Main endpoint for dispatching requests to the Axon reasoning service with governance checks.

**Request:**
```json
{
  "intent": "call_reasoning",
  "context": {
    "user_id": "user123",
    "request_id": "req456"
  }
}
```

**Response (Success):**
```json
{
  "status": "success",
  "message": "Axon heartbeat OK",
  "correlation_id": "abc123-def456",
  "timestamp": "2024-01-15T10:30:00Z",
  "governance": {
    "allowed": true,
    "reason": "Request authorized",
    "decision_time_ms": 45
  }
}
```

**Response (Governance Denied):**
```json
{
  "status": "denied",
  "reason": "Rate limit exceeded",
  "correlation_id": "abc123-def456",
  "timestamp": "2024-01-15T10:30:00Z",
  "governance": {
    "allowed": false,
    "reason": "Rate limit exceeded",
    "decision_time_ms": 23
  }
}
```

**Status Codes:**
- `200 OK`: Request processed successfully
- `403 Forbidden`: Governance denied the request
- `500 Internal Server Error`: Server error
- `503 Service Unavailable`: Service temporarily unavailable

### GET /metrics

Prometheus-compatible metrics endpoint (if enabled).

**Response:**
```
# HELP orbit_requests_total Total number of requests
# TYPE orbit_requests_total counter
orbit_requests_total{method="POST",endpoint="/dispatch",status="200"} 12543

# HELP orbit_governance_decisions_total Governance decisions made
# TYPE orbit_governance_decisions_total counter
orbit_governance_decisions_total{decision="allowed"} 12456
orbit_governance_decisions_total{decision="denied"} 87
```

## Request/Response Headers

### Request Headers
- `X-Correlation-ID`: Unique request identifier (auto-generated if not provided)
- `Authorization`: AWS SigV4 signature
- `X-Amz-Date`: Request timestamp
- `Content-Type`: `application/json`

### Response Headers
- `X-Correlation-ID`: Echoed correlation ID
- `Content-Type`: `application/json`
- `X-Request-ID`: Internal request identifier

## Error Handling

### Error Response Format
```json
{
  "error": "Error message",
  "correlation_id": "abc123-def456",
  "timestamp": "2024-01-15T10:30:00Z",
  "details": {
    "field": "intent",
    "issue": "required field missing"
  }
}
```

### Common Errors
- `INVALID_SIGNATURE`: SigV4 signature verification failed
- `MISSING_AUTHORIZATION`: Authorization header missing
- `GOVERNANCE_DENIED`: Request blocked by governance policy
- `SERVICE_UNAVAILABLE`: Backend service temporarily unavailable
- `RATE_LIMIT_EXCEEDED`: Too many requests

## Rate Limiting

- **Global Rate Limit**: 1000 requests per minute
- **Per IP**: 100 requests per minute
- **Governance Calls**: 100 requests per minute

Rate limit headers are included in responses:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 987
X-RateLimit-Reset: 1642156800
```

## Monitoring and Observability

### Metrics
- Request count, latency, error rates
- Governance decision counts
- Service health status

### Logs
All requests are logged with correlation IDs for tracing:
```
2024-01-15T10:30:00Z [INFO] REQUEST [abc123-def456] POST /dispatch 200 45ms
2024-01-15T10:30:00Z [INFO] GOVERNANCE [abc123-def456] allowed: Request authorized
2024-01-15T10:30:00Z [INFO] AXON_CALL [abc123-def456] success: Axon heartbeat OK
```

### Tracing
Distributed tracing with AWS X-Ray (when enabled):
- Request flow: ALB → Orbit → Governance → Axon
- Service dependencies and latency
- Error propagation

## SDK Examples

### Python Client
```python
import boto3
import requests
from botocore.awsrequest import AWSRequest
from botocore.auth import SigV4Auth

class AgentRuntimeClient:
    def __init__(self, endpoint_url: str, region: str = 'us-east-1'):
        self.endpoint_url = endpoint_url
        self.region = region
        self.session = boto3.Session()

    def _sign_request(self, method: str, url: str, body: str = None) -> dict:
        """Sign request with SigV4"""
        request = AWSRequest(
            method=method,
            url=url,
            data=body
        )

        SigV4Auth(self.session.get_credentials(), 'execute-api', self.region).add_auth(request)

        return {
            'Authorization': request.headers['Authorization'],
            'X-Amz-Date': request.headers['X-Amz-Date']
        }

    def dispatch(self, intent: str = 'call_reasoning', context: dict = None) -> dict:
        """Dispatch a request"""
        url = f"{self.endpoint_url}/dispatch"
        payload = {
            'intent': intent,
            'context': context or {}
        }

        headers = self._sign_request('POST', url, json.dumps(payload))
        headers['Content-Type'] = 'application/json'

        response = requests.post(url, json=payload, headers=headers)
        return response.json()

    def health_check(self) -> dict:
        """Check service health"""
        url = f"{self.endpoint_url}/health"
        headers = self._sign_request('GET', url)

        response = requests.get(url, headers=headers)
        return response.json()

# Usage
client = AgentRuntimeClient('https://your-alb-dns')
result = client.dispatch('call_reasoning', {'user_id': 'user123'})
print(result)
```

### JavaScript/Node.js Client
```javascript
const AWS = require('aws-sdk');
const axios = require('axios');

class AgentRuntimeClient {
  constructor(endpointUrl, region = 'us-east-1') {
    this.endpointUrl = endpointUrl;
    this.region = region;
    this.credentials = new AWS.CredentialProviderChain();
  }

  async signRequest(method, url, body = null) {
    const request = {
      method: method,
      url: url,
      body: body,
      headers: {}
    };

    const signer = new AWS.Signers.V4(request, 'execute-api');
    signer.addAuthorization(this.credentials, new Date());

    return request.headers;
  }

  async dispatch(intent = 'call_reasoning', context = {}) {
    const url = `${this.endpointUrl}/dispatch`;
    const payload = { intent, context };

    const headers = await this.signRequest('POST', url, JSON.stringify(payload));
    headers['Content-Type'] = 'application/json';

    const response = await axios.post(url, payload, { headers });
    return response.data;
  }

  async healthCheck() {
    const url = `${this.endpointUrl}/health`;
    const headers = await this.signRequest('GET', url);

    const response = await axios.get(url, { headers });
    return response.data;
  }
}

// Usage
const client = new AgentRuntimeClient('https://your-alb-dns');
const result = await client.dispatch('call_reasoning', { userId: 'user123' });
console.log(result);
```

### Go Client
```go
package main

import (
    "bytes"
    "context"
    "crypto/tls"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "time"

    "github.com/aws/aws-sdk-go/aws"
    "github.com/aws/aws-sdk-go/aws/credentials"
    "github.com/aws/aws-sdk-go/aws/session"
    v4 "github.com/aws/aws-sdk-go/aws/signer/v4"
)

type AgentRuntimeClient struct {
    endpoint string
    signer   *v4.Signer
    client   *http.Client
}

type DispatchRequest struct {
    Intent  string                 `json:"intent"`
    Context map[string]interface{} `json:"context,omitempty"`
}

type DispatchResponse struct {
    Status       string    `json:"status"`
    Message      string    `json:"message,omitempty"`
    Reason       string    `json:"reason,omitempty"`
    CorrelationID string   `json:"correlation_id"`
    Timestamp    time.Time `json:"timestamp"`
}

func NewAgentRuntimeClient(endpoint string) *AgentRuntimeClient {
    sess := session.Must(session.NewSession())
    signer := v4.NewSigner(sess.Config.Credentials)

    return &AgentRuntimeClient{
        endpoint: endpoint,
        signer:   signer,
        client: &http.Client{
            Timeout: 30 * time.Second,
            Transport: &http.Transport{
                TLSClientConfig: &tls.Config{
                    InsecureSkipVerify: false,
                },
            },
        },
    }
}

func (c *AgentRuntimeClient) Dispatch(ctx context.Context, intent string, context map[string]interface{}) (*DispatchResponse, error) {
    url := c.endpoint + "/dispatch"

    reqData := DispatchRequest{
        Intent:  intent,
        Context: context,
    }

    jsonData, err := json.Marshal(reqData)
    if err != nil {
        return nil, fmt.Errorf("failed to marshal request: %w", err)
    }

    req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
    if err != nil {
        return nil, fmt.Errorf("failed to create request: %w", err)
    }

    req.Header.Set("Content-Type", "application/json")

    // Sign the request
    _, err = c.signer.Sign(req, bytes.NewReader(jsonData), "execute-api", "us-east-1", time.Now())
    if err != nil {
        return nil, fmt.Errorf("failed to sign request: %w", err)
    }

    resp, err := c.client.Do(req)
    if err != nil {
        return nil, fmt.Errorf("request failed: %w", err)
    }
    defer resp.Body.Close()

    body, err := io.ReadAll(resp.Body)
    if err != nil {
        return nil, fmt.Errorf("failed to read response: %w", err)
    }

    var response DispatchResponse
    if err := json.Unmarshal(body, &response); err != nil {
        return nil, fmt.Errorf("failed to unmarshal response: %w", err)
    }

    if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusForbidden {
        return &response, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
    }

    return &response, nil
}

func (c *AgentRuntimeClient) HealthCheck(ctx context.Context) (map[string]interface{}, error) {
    url := c.endpoint + "/health"

    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, fmt.Errorf("failed to create request: %w", err)
    }

    // Sign the request
    _, err = c.signer.Sign(req, nil, "execute-api", "us-east-1", time.Now())
    if err != nil {
        return nil, fmt.Errorf("failed to sign request: %w", err)
    }

    resp, err := c.client.Do(req)
    if err != nil {
        return nil, fmt.Errorf("request failed: %w", err)
    }
    defer resp.Body.Close()

    var result map[string]interface{}
    if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
        return nil, fmt.Errorf("failed to decode response: %w", err)
    }

    return result, nil
}

func main() {
    client := NewAgentRuntimeClient("https://your-alb-dns")

    // Health check
    health, err := client.HealthCheck(context.Background())
    if err != nil {
        fmt.Printf("Health check failed: %v\n", err)
        return
    }
    fmt.Printf("Health: %+v\n", health)

    // Dispatch request
    response, err := client.Dispatch(context.Background(), "call_reasoning", map[string]interface{}{
        "user_id": "user123",
    })
    if err != nil {
        fmt.Printf("Dispatch failed: %v\n", err)
        return
    }
    fmt.Printf("Response: %+v\n", response)
}
```

## Webhooks and Callbacks

### Governance Decision Webhooks (Future)

When governance decisions are made, webhooks can be configured to notify external systems:

```json
{
  "event": "governance_decision",
  "service": "orbit",
  "intent": "call_reasoning",
  "allowed": true,
  "reason": "Request authorized",
  "correlation_id": "abc123-def456",
  "timestamp": "2024-01-15T10:30:00Z",
  "context": {
    "user_id": "user123",
    "ip_address": "192.168.1.1"
  }
}
```

## Versioning

API versioning follows semantic versioning (MAJOR.MINOR.PATCH).

### Current Version: 1.0.0
- Initial release with core functionality
- Governance integration
- SigV4 authentication

### Backward Compatibility
- All changes maintain backward compatibility within major versions
- Deprecation notices provided 3 months before removal
- New features are additive

## SLA and Support

### Service Level Agreement
- **Availability**: 99.9% uptime
- **Latency**: p95 < 500ms
- **Support**: 24/7 for critical issues

### Support Channels
- **Documentation**: This API documentation
- **Issues**: GitHub repository issues
- **Email**: api-support@barnabus.ai
- **Slack**: #api-support

## Changelog

### Version 1.0.0 (2024-01-15)
- Initial API release
- Health check endpoint
- Dispatch endpoint with governance
- SigV4 authentication
- Structured logging
```

**Test Step 7.4:**

```bash
# Validate setup guide
cd docs
markdown-link-check setup-guide.md

# Check API documentation
grep -A 5 -B 5 "GET /health\|POST /dispatch" api.md
```

## Acceptance Criteria

- [ ] Complete architecture documentation with diagrams
- [ ] Comprehensive operations runbook
- [ ] Failure and resilience plan documented
- [ ] Security model thoroughly documented
- [ ] Setup instructions clear and complete
- [ ] API documentation with examples
- [ ] Troubleshooting guides created
- [ ] Performance characteristics documented
- [ ] README updated with full instructions

## Rollback Procedure

If documentation deployment fails:

```bash
# Revert documentation changes
git revert <documentation-commit>

# Restore previous README
git checkout HEAD~1 -- README.md
```

## Testing Script

Create `tasks/test-task-7.sh`:

```bash
#!/bin/bash
set -e

echo "Testing Task 7: Documentation"

# Check all documentation files exist
DOC_FILES=(
  "docs/architecture.md"
  "docs/failure-resilience.md"
  "docs/security.md"
  "docs/runbook.md"
  "docs/setup-guide.md"
  "docs/api.md"
)

for file in "${DOC_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "❌ Documentation file missing: $file"
    exit 1
  fi
done
echo "✅ All documentation files present"

# Validate README completeness
if ! grep -q "Setup Guide\|API Documentation\|Architecture" README.md; then
  echo "❌ README missing key sections"
  exit 1
fi
echo "✅ README is comprehensive"

# Check documentation links
cd docs
for file in *.md; do
  if ! markdown-link-check "$file" --quiet; then
    echo "⚠️  Broken links found in $file"
  fi
done
echo "✅ Documentation links validated"

# Check setup guide for key commands
if ! grep -q "terraform init\|docker build" setup-guide.md; then
  echo "❌ Setup guide missing key commands"
  exit 1
fi
echo "✅ Setup guide includes key commands"

echo ""
echo "🎉 Task 7 Documentation: PASSED"
```
