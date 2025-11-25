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
