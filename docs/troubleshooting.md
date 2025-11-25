# Troubleshooting Guide

This guide covers common issues and their solutions for the AWS Agent Runtime system.

## Quick Health Check

Run this first when experiencing issues:

```bash
# Check overall system health
./scripts/health-check.sh

# Check specific services
aws ecs describe-services --cluster ${PROJECT_NAME}-cluster \
    --services ${PROJECT_NAME}-axon ${PROJECT_NAME}-orbit \
    --query 'services[*].{name:serviceName,status:status,running:runningCount,desired:desiredCount}'
```

## Common Issues

### Service Deployment Issues

#### ECS Service Stuck in PENDING State

**Symptoms:**
- Service shows `PENDING` status
- Tasks not starting
- No error messages in logs

**Causes:**
- Insufficient capacity
- Network configuration issues
- Task definition problems

**Solutions:**
```bash
# Check cluster capacity
aws ecs describe-clusters --clusters ${PROJECT_NAME}-cluster \
    --query 'clusters[0].{registeredContainerInstancesCount:registeredContainerInstancesCount,runningTasksCount:runningTasksCount}'

# Check service events
aws ecs describe-services --cluster ${PROJECT_NAME}-cluster \
    --services ${PROJECT_NAME}-axon \
    --query 'services[0].events[0:5]'

# Force deployment
aws ecs update-service --cluster ${PROJECT_NAME}-cluster \
    --service ${PROJECT_NAME}-axon \
    --force-new-deployment
```

#### Container Health Checks Failing

**Symptoms:**
- Tasks restart repeatedly
- Health check endpoint returns 5xx

**Solutions:**
```bash
# Check task logs
aws logs tail /ecs/${PROJECT_NAME}-axon --follow

# Check task status
TASK_ARN=$(aws ecs list-tasks --cluster ${PROJECT_NAME}-cluster \
    --service-name ${PROJECT_NAME}-axon \
    --query 'taskArns[0]' --output text)

aws ecs describe-tasks --cluster ${PROJECT_NAME}-cluster --tasks $TASK_ARN

# Restart service
aws ecs update-service --cluster ${PROJECT_NAME}-cluster \
    --service ${PROJECT_NAME}-axon \
    --desired-count 0

aws ecs update-service --cluster ${PROJECT_NAME}-cluster \
    --service ${PROJECT_NAME}-axon \
    --desired-count 2
```

### Network Issues

#### ALB Target Group Health Checks Failing

**Symptoms:**
- ALB shows unhealthy targets
- 502/503 errors from API

**Solutions:**
```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN

# Verify security groups
aws ec2 describe-security-groups --group-ids $ALB_SG $ECS_SG

# Check network ACLs
aws ec2 describe-network-acls --filters Name=vpc-id,Values=$VPC_ID
```

#### Cross-Service Communication Failing

**Symptoms:**
- Orbit can't reach Axon
- Governance calls fail
- Timeout errors in logs

**Solutions:**
```bash
# Check App Mesh configuration
aws app-mesh describe-mesh --mesh-name ${PROJECT_NAME}-mesh

# Verify service discovery
aws servicediscovery list-services --namespace-id $NAMESPACE_ID

# Check CloudMap services
aws servicediscovery list-instances \
    --service-id $AXON_SERVICE_ID \
    --query 'Instances[0]'
```

### Authentication Issues

#### SigV4 Signature Verification Failing

**Symptoms:**
- 401 Unauthorized responses
- "INVALID_SIGNATURE" errors

**Solutions:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify region configuration
aws configure list

# Test with known good credentials
aws lambda invoke --function-name test-signer output.json \
    --payload '{"test": "data"}'
```

#### Governance Policy Denials

**Symptoms:**
- 403 Forbidden responses
- "GOVERNANCE_DENIED" errors
- High denial rates in metrics

**Solutions:**
```bash
# Check policy configuration
aws dynamodb scan --table-name ${PROJECT_NAME}-governance-policies

# Review governance logs
aws logs filter-log-events \
    --log-group-name /aws/lambda/${PROJECT_NAME}-governance \
    --filter-pattern "DENIED"

# Update policies
cd governance/scripts
python update-policies.py
```

### Performance Issues

#### High Latency

**Symptoms:**
- p95 latency > 500ms
- Slow response times
- Timeout errors

**Solutions:**
```bash
# Check resource utilization
aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name CPUUtilization \
    --statistics Maximum \
    --start-time $(date -u -d '1 hour ago' +%s)

# Scale services
aws ecs update-service --cluster ${PROJECT_NAME}-cluster \
    --service ${PROJECT_NAME}-axon \
    --desired-count 4

# Check Lambda performance
aws lambda get-function --function-name ${PROJECT_NAME}-governance \
    --query '{MemorySize:MemorySize,Timeout:Timeout}'
```

#### Memory Issues

**Symptoms:**
- Out of memory errors
- Container restarts
- High memory utilization

**Solutions:**
```bash
# Check current memory allocation
aws ecs describe-task-definition \
    --task-definition ${PROJECT_NAME}-axon \
    --query 'taskDefinition.memory'

# Update task definition
aws ecs register-task-definition \
    --cli-input-json file://infra/modules/ecs/task-definitions/axon-updated.json

# Deploy updated version
aws ecs update-service --cluster ${PROJECT_NAME}-cluster \
    --service ${PROJECT_NAME}-axon \
    --force-new-deployment
```

### Database Issues

#### DynamoDB Throttling

**Symptoms:**
- Read/Write capacity exceeded
- Slow governance responses
- ThrottlingException errors

**Solutions:**
```bash
# Check table capacity
aws dynamodb describe-table --table-name ${PROJECT_NAME}-governance-policies \
    --query 'Table.{TableStatus:TableStatus,BillingModeSummary:BillingModeSummary}'

# Switch to on-demand
aws dynamodb update-table --table-name ${PROJECT_NAME}-governance-policies \
    --billing-mode PAY_PER_REQUEST

# Monitor throttling
aws cloudwatch get-metric-statistics \
    --namespace AWS/DynamoDB \
    --metric-name ThrottledRequests \
    --statistics Sum
```

#### Data Consistency Issues

**Symptoms:**
- Inconsistent policy decisions
- Stale data in responses
- Replication lag

**Solutions:**
```bash
# Check DynamoDB streams
aws dynamodbstreams describe-stream \
    --stream-arn $(aws dynamodb describe-table \
        --table-name ${PROJECT_NAME}-governance-policies \
        --query 'Table.LatestStreamArn' --output text)

# Verify Lambda trigger
aws lambda list-event-source-mappings \
    --function-name ${PROJECT_NAME}-governance \
    --query 'EventSourceMappings[0].State'
```

### Monitoring Issues

#### Missing Metrics

**Symptoms:**
- No data in CloudWatch dashboards
- Missing alarms
- Log groups not created

**Solutions:**
```bash
# Check CloudWatch agent
aws logs describe-log-groups --log-group-name-prefix "/ecs/${PROJECT_NAME}"

# Verify IAM permissions
aws iam list-attached-role-policies \
    --role-name ${PROJECT_NAME}-ecs-task-role

# Recreate log groups
aws logs create-log-group --log-group-name /ecs/${PROJECT_NAME}-axon
aws logs create-log-group --log-group-name /ecs/${PROJECT_NAME}-orbit
```

#### Alert Fatigue

**Symptoms:**
- Too many false alarms
- Important alerts missed
- High notification volume

**Solutions:**
```bash
# Review alarm thresholds
aws cloudwatch describe-alarms --alarm-name-prefix "${PROJECT_NAME}" \
    --query 'MetricAlarms[*].{AlarmName:AlarmName,Threshold:Threshold}'

# Adjust alarm configuration
aws cloudwatch put-metric-alarm \
    --alarm-name "${PROJECT_NAME}-high-cpu-adjusted" \
    --alarm-description "Adjusted CPU alarm" \
    --metric-name CPUUtilization \
    --namespace AWS/ECS \
    --statistic Average \
    --period 300 \
    --threshold 75 \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=ClusterName,Value=${PROJECT_NAME}-cluster \
    --evaluation-periods 2
```

### Security Issues

#### Unexpected Access Patterns

**Symptoms:**
- Unusual traffic spikes
- Unknown IP addresses
- Suspicious API calls

**Solutions:**
```bash
# Check CloudTrail logs
aws cloudtrail lookup-events \
    --start-time $(date -u -d '1 hour ago' +%s) \
    --lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRole

# Review VPC flow logs
aws ec2 describe-flow-logs --query 'FlowLogs[*].FlowLogId'

# Update security groups
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG \
    --protocol tcp \
    --port 80 \
    --cidr 10.0.0.0/8
```

#### Certificate Issues

**Symptoms:**
- SSL/TLS handshake failures
- Certificate expired errors
- HTTPS connection failures

**Solutions:**
```bash
# Check ACM certificate
aws acm list-certificates --query 'CertificateSummaryList[?DomainName==`*.yourdomain.com`]'

# Renew certificate
aws acm renew-certificate --certificate-arn $CERT_ARN

# Update ALB listener
aws elbv2 modify-listener \
    --listener-arn $LISTENER_ARN \
    --certificates CertificateArn=$NEW_CERT_ARN
```

## Diagnostic Scripts

### System Health Check
```bash
#!/bin/bash
# scripts/health-check.sh

echo "🔍 AWS Agent Runtime Health Check"
echo "=================================="

# Check ECS services
echo "ECS Services:"
aws ecs describe-services --cluster ${PROJECT_NAME}-cluster \
    --services ${PROJECT_NAME}-axon ${PROJECT_NAME}-orbit \
    --query 'services[*].{Name:serviceName,Status:status,Running:runningCount,Desired:desiredCount}' \
    --output table

# Check Lambda function
echo -e "\nGovernance Lambda:"
aws lambda get-function --function-name ${PROJECT_NAME}-governance \
    --query '{State:State,LastModified:LastModified}'

# Check DynamoDB
echo -e "\nDynamoDB Table:"
aws dynamodb describe-table --table-name ${PROJECT_NAME}-governance-policies \
    --query '{Status:TableStatus,ItemCount:ItemCount}'

# Check ALB
echo -e "\nALB Health:"
ALB_DNS=$(aws elbv2 describe-load-balancers --names ${PROJECT_NAME}-alb \
    --query 'LoadBalancers[0].DNSName' --output text)
curl -f -s https://$ALB_DNS/health && echo "✅ ALB healthy" || echo "❌ ALB unhealthy"

echo -e "\nHealth check complete."
```

### Performance Diagnostic
```bash
#!/bin/bash
# scripts/performance-check.sh

echo "📊 Performance Diagnostics"
echo "=========================="

# CPU Utilization (last hour)
echo "ECS CPU Utilization:"
aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name CPUUtilization \
    --statistics Average,Maximum \
    --start-time $(date -u -d '1 hour ago' +%s) \
    --end-time $(date -u +%s) \
    --period 3600 \
    --dimensions Name=ClusterName,Value=${PROJECT_NAME}-cluster

# Lambda Duration
echo -e "\nGovernance Lambda Duration:"
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Duration \
    --statistics p95 \
    --start-time $(date -u -d '1 hour ago' +%s) \
    --dimensions Name=FunctionName,Value=${PROJECT_NAME}-governance

# Error Rates
echo -e "\nError Rates:"
aws cloudwatch get-metric-statistics \
    --namespace ${PROJECT_NAME}/Axon \
    --metric-name ErrorCount \
    --statistics Sum \
    --start-time $(date -u -d '1 hour ago' +%s)
```

## Escalation Procedures

### When to Escalate

1. **Immediate Escalation (P0):**
   - Complete system outage
   - Security breach
   - Data loss

2. **High Priority (P1):**
   - Major functionality degraded
   - Performance severely impacted
   - Customer-facing issues

3. **Normal Priority (P2):**
   - Minor issues
   - Intermittent problems
   - Non-critical functionality

### Escalation Contacts

- **Primary On-Call:** SRE Team Lead
- **Secondary:** DevOps Manager
- **Security Issues:** Security Team
- **Vendor Issues:** AWS Support

## Prevention

### Proactive Monitoring

Set up comprehensive monitoring:

```bash
# Create key alarms
aws cloudwatch put-metric-alarm \
    --alarm-name "${PROJECT_NAME}-system-health" \
    --alarm-description "System health check" \
    --metric-name HealthyHostCount \
    --namespace AWS/NetworkELB \
    --statistic Minimum \
    --period 60 \
    --threshold 1 \
    --comparison-operator LessThanThreshold \
    --dimensions Name=LoadBalancer,Value=$ALB_ARN \
    --evaluation-periods 2
```

### Regular Maintenance

Schedule regular maintenance tasks:

- Weekly: Log rotation, security scans
- Monthly: Dependency updates, performance tuning
- Quarterly: Architecture reviews, capacity planning

### Backup Verification

Regularly test backup and recovery procedures:

```bash
# Test backup restoration
aws dynamodb restore-table-from-backup \
    --target-table-name ${PROJECT_NAME}-test-restore \
    --backup-arn $BACKUP_ARN

# Verify data integrity
aws dynamodb scan --table-name ${PROJECT_NAME}-test-restore \
    --select COUNT
```

## Getting Help

If you can't resolve an issue:

1. **Check Documentation:** Review this troubleshooting guide and related docs
2. **Search Issues:** Check GitHub repository for similar issues
3. **Create Issue:** Open a new issue with detailed information
4. **Contact Support:** Reach out to the support team

### Required Information for Support

When creating support tickets, include:

- Environment (dev/staging/prod)
- Timeline of the issue
- Affected services/endpoints
- Error messages and logs
- Steps to reproduce
- Recent changes or deployments
- System health check output
