# Task 5: Observability Setup

**Duration:** 5-7 hours
**Priority:** High
**Dependencies:** Tasks 1, 2 (Infrastructure, Microservices)

## Overview

Implement comprehensive observability including CloudWatch dashboards, structured logging, alerting, and distributed tracing to monitor the agent runtime environment.

## Objectives

- [ ] CloudWatch dashboards for service health and metrics
- [ ] Structured JSON logging with correlation IDs
- [ ] CloudWatch Insights queries for troubleshooting
- [ ] SNS-based alerting for critical events
- [ ] X-Ray distributed tracing (optional)
- [ ] Custom CloudWatch metrics
- [ ] Log retention and archival policies
- [ ] Service mesh observability

## Prerequisites

- [ ] Tasks 1 and 2 completed
- [ ] Services deployed to ECS
- [ ] CloudWatch logs configured
- [ ] Basic monitoring in place

## File Structure

```
observability/
├── dashboards/
│   ├── main-dashboard.json
│   ├── service-health-dashboard.json
│   └── governance-dashboard.json
├── terraform/
│   ├── dashboards.tf
│   ├── alarms.tf
│   ├── logs.tf
│   ├── sns.tf
│   ├── variables.tf
│   └── outputs.tf
├── logging/
│   ├── queries.json
│   └── log-config.json
├── metrics/
│   ├── custom-metrics.json
│   └── definitions.json
└── scripts/
    ├── create-dashboards.sh
    ├── test-alerts.sh
    └── metric-report.sh
```

## Implementation Steps

### Step 5.1: CloudWatch Dashboards (2-3 hours)

**File: observability/dashboards/main-dashboard.json**

```json
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ECS", "CPUUtilization", "ServiceName", "${PROJECT_NAME}-axon", "ClusterName", "${PROJECT_NAME}-cluster"],
          [".", ".", ".", "${PROJECT_NAME}-orbit", ".", "."]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "title": "ECS Service CPU Utilization",
        "period": 300,
        "stat": "Average"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ECS", "MemoryUtilization", "ServiceName", "${PROJECT_NAME}-axon", "ClusterName", "${PROJECT_NAME}-cluster"],
          [".", ".", ".", "${PROJECT_NAME}-orbit", ".", "."]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "title": "ECS Service Memory Utilization",
        "period": 300,
        "stat": "Average"
      }
    },
    {
      "type": "log",
      "x": 0,
      "y": 6,
      "width": 24,
      "height": 6,
      "properties": {
        "query": "fields @timestamp, @message\n| filter @message like /ERROR/ or @message like /WARN/\n| sort @timestamp desc\n| limit 100",
        "region": "${AWS_REGION}",
        "title": "Recent Errors and Warnings",
        "view": "table"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 12,
      "width": 8,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApiGateway", "Count", "ApiName", "${PROJECT_NAME}-governance", "Method", "POST", "Resource", "/govern"]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "title": "Governance API Calls",
        "period": 300,
        "stat": "Sum"
      }
    },
    {
      "type": "metric",
      "x": 8,
      "y": 12,
      "width": 8,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/Lambda", "Duration", "FunctionName", "${PROJECT_NAME}-governance"]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "title": "Governance Lambda Duration",
        "period": 300,
        "stat": "Average"
      }
    },
    {
      "type": "metric",
      "x": 16,
      "y": 12,
      "width": 8,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/Lambda", "Errors", "FunctionName", "${PROJECT_NAME}-governance"]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "title": "Governance Lambda Errors",
        "period": 300,
        "stat": "Sum"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 18,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ECS", "RunningTaskCount", "ServiceName", "${PROJECT_NAME}-axon", "ClusterName", "${PROJECT_NAME}-cluster"],
          [".", ".", ".", "${PROJECT_NAME}-orbit", ".", "."]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "title": "Running Tasks Count",
        "period": 300,
        "stat": "Average"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 18,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["LogMetrics", "ErrorRate", "LogGroup", "/ecs/${PROJECT_NAME}-axon"],
          [".", ".", ".", "/ecs/${PROJECT_NAME}-orbit"],
          [".", ".", ".", "/aws/lambda/${PROJECT_NAME}-governance"]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "title": "Error Rates",
        "period": 300,
        "stat": "Average"
      }
    }
  ]
}
```

**File: observability/terraform/dashboards.tf**

```hcl
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-main-dashboard"

  dashboard_body = templatefile("${path.module}/../dashboards/main-dashboard.json", {
    PROJECT_NAME = var.project_name
    AWS_REGION   = var.aws_region
  })
}

resource "aws_cloudwatch_dashboard" "service_health" {
  dashboard_name = "${var.project_name}-service-health"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x = 0
        y = 0
        width = 24
        height = 8
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "${var.project_name}-axon", "ClusterName", "${var.project_name}-cluster", { "stat": "Maximum", "label": "Axon CPU Max" }],
            [".", ".", ".", "${var.project_name}-orbit", ".", ".", { "stat": "Maximum", "label": "Orbit CPU Max" }],
            [".", ".", ".", "${var.project_name}-axon", ".", ".", { "stat": "Average", "label": "Axon CPU Avg" }],
            [".", ".", ".", "${var.project_name}-orbit", ".", ".", { "stat": "Average", "label": "Orbit CPU Avg" }]
          ]
          view = "timeSeries"
          stacked = false
          region = var.aws_region
          title = "Service CPU Utilization"
          period = 300
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "governance" {
  dashboard_name = "${var.project_name}-governance"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x = 0
        y = 0
        width = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.project_name}-governance"]
          ]
          view = "timeSeries"
          stacked = false
          region = var.aws_region
          title = "Governance Invocations"
          period = 300
          stat = "Sum"
        }
      },
      {
        type = "metric"
        x = 12
        y = 0
        width = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", "${var.project_name}-governance", { "stat": "p95" }],
            [".", ".", ".", ".", { "stat": "p99" }]
          ]
          view = "timeSeries"
          stacked = false
          region = var.aws_region
          title = "Governance Latency (p95/p99)"
          period = 300
        }
      },
      {
        type = "log"
        x = 0
        y = 6
        width = 24
        height = 6
        properties = {
          query = "fields @timestamp, service, intent, allowed, reason, correlation_id\n| filter ispresent(allowed)\n| sort @timestamp desc\n| limit 50"
          region = var.aws_region
          title = "Recent Governance Decisions"
          view = "table"
        }
      }
    ]
  })
}
```

**Test Step 5.1:**

```bash
cd observability/terraform
terraform plan
terraform apply

# Check dashboards created
aws cloudwatch list-dashboards --query 'DashboardEntries[*].DashboardName'
```

### Step 5.2: Logging Configuration (1-2 hours)

**File: observability/logging/queries.json**

```json
{
  "queries": {
    "error_analysis": {
      "query": "fields @timestamp, @message, correlation_id, service\n| filter level = \"ERROR\"\n| sort @timestamp desc\n| limit 100",
      "description": "Find all errors with correlation IDs"
    },
    "request_tracing": {
      "query": "fields @timestamp, @message, correlation_id, method, url\n| filter ispresent(correlation_id)\n| sort @timestamp desc\n| limit 50",
      "description": "Trace requests across services"
    },
    "governance_decisions": {
      "query": "fields @timestamp, service, intent, allowed, reason, correlation_id\n| filter ispresent(allowed)\n| stats count() by bin(5m), allowed\n| sort @timestamp desc",
      "description": "Analyze governance decision patterns"
    },
    "performance_analysis": {
      "query": "fields @timestamp, duration, service, operation\n| filter ispresent(duration)\n| stats avg(duration), max(duration), min(duration) by bin(1m), service\n| sort @timestamp desc",
      "description": "Performance metrics over time"
    },
    "security_events": {
      "query": "fields @timestamp, @message, source_ip, user_agent\n| filter @message like /DENIED/ or @message like /BLOCKED/\n| sort @timestamp desc\n| limit 50",
      "description": "Security-related events"
    }
  }
}
```

**File: observability/terraform/logs.tf**

```hcl
# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "axon" {
  name              = "/ecs/${var.project_name}-axon"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "${var.project_name}-axon-logs"
    Service     = "axon"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "orbit" {
  name              = "/ecs/${var.project_name}-orbit"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "${var.project_name}-orbit-logs"
    Service     = "orbit"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "governance" {
  name              = "/aws/lambda/${var.project_name}-governance"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = {
    Name        = "${var.project_name}-governance-logs"
    Service     = "governance"
    Environment = var.environment
  }
}

# Log Metric Filters for custom metrics
resource "aws_cloudwatch_log_metric_filter" "axon_errors" {
  name           = "${var.project_name}-axon-errors"
  pattern        = "\"level\":\"ERROR\""
  log_group_name = aws_cloudwatch_log_group.axon.name

  metric_transformation {
    name      = "ErrorCount"
    namespace = "${var.project_name}/Axon"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "orbit_requests" {
  name           = "${var.project_name}-orbit-requests"
  pattern        = "\"REQUEST\""
  log_group_name = aws_cloudwatch_log_group.orbit.name

  metric_transformation {
    name      = "RequestCount"
    namespace = "${var.project_name}/Orbit"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "governance_denials" {
  name           = "${var.project_name}-governance-denials"
  pattern        = "\"allowed\":false"
  log_group_name = aws_cloudwatch_log_group.governance.name

  metric_transformation {
    name      = "DenialCount"
    namespace = "${var.project_name}/Governance"
    value     = "1"
    unit      = "Count"
  }
}

# Log Insights queries
resource "aws_cloudwatch_query_definition" "error_analysis" {
  name = "${var.project_name}/error-analysis"

  log_group_names = [
    aws_cloudwatch_log_group.axon.name,
    aws_cloudwatch_log_group.orbit.name,
    aws_cloudwatch_log_group.governance.name
  ]

  query_string = <<EOF
fields @timestamp, @message, correlation_id, service, level
| filter level = "ERROR" or level = "WARN"
| sort @timestamp desc
| limit 100
EOF
}

resource "aws_cloudwatch_query_definition" "request_tracing" {
  name = "${var.project_name}/request-tracing"

  log_group_names = [
    aws_cloudwatch_log_group.orbit.name,
    aws_cloudwatch_log_group.governance.name,
    aws_cloudwatch_log_group.axon.name
  ]

  query_string = <<EOF
fields @timestamp, @message, correlation_id, service, operation
| filter ispresent(correlation_id)
| sort @timestamp desc, correlation_id
| limit 100
EOF
}
```

**Test Step 5.2:**

```bash
# Test log groups created
aws logs describe-log-groups --log-group-name-prefix "/ecs/${PROJECT_NAME}"

# Test metric filters
aws logs describe-metric-filters --log-group-name "/ecs/${PROJECT_NAME}-axon"
```

### Step 5.3: Alerting Setup (1-2 hours)

**File: observability/terraform/sns.tf**

```hcl
resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alerts"
  kms_master_key_id = var.kms_key_arn

  tags = {
    Name = "${var.project_name}-alerts"
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "SNS:Publish"
        ]
        Resource = aws_sns_topic.alerts.arn
        Condition = {
          StringEquals = {
            "AWS:SourceOwner" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Email subscription (for testing - replace with PagerDuty in production)
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
```

**File: observability/terraform/alarms.tf**

```hcl
# Service Health Alarms
resource "aws_cloudwatch_metric_alarm" "axon_cpu_high" {
  alarm_name          = "${var.project_name}-axon-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Axon service CPU utilization is high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = "${var.project_name}-cluster"
    ServiceName = "${var.project_name}-axon"
  }

  tags = {
    Name = "${var.project_name}-axon-cpu-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "axon_memory_high" {
  alarm_name          = "${var.project_name}-axon-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Axon service memory utilization is high"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = "${var.project_name}-cluster"
    ServiceName = "${var.project_name}-axon"
  }
}

resource "aws_cloudwatch_metric_alarm" "orbit_down" {
  alarm_name          = "${var.project_name}-orbit-service-down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2"
  alarm_description   = "Orbit service has fewer than 2 running tasks"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = "${var.project_name}-cluster"
    ServiceName = "${var.project_name}-orbit"
  }
}

# Governance Alarms
resource "aws_cloudwatch_metric_alarm" "governance_errors" {
  alarm_name          = "${var.project_name}-governance-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Governance Lambda has errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = "${var.project_name}-governance"
  }
}

resource "aws_cloudwatch_metric_alarm" "governance_high_denials" {
  alarm_name          = "${var.project_name}-governance-high-denials"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DenialCount"
  namespace           = "${var.project_name}/Governance"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "High number of governance denials detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "governance_latency" {
  alarm_name          = "${var.project_name}-governance-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "p95"
  threshold           = "1000"
  alarm_description   = "Governance Lambda p95 latency > 1s"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = "${var.project_name}-governance"
  }
}

# Error Rate Alarms
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.project_name}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ErrorCount"
  namespace           = "${var.project_name}/Axon"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "High error rate detected (>10 errors in 5 minutes)"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# Composite Alarm for Service Health
resource "aws_cloudwatch_composite_alarm" "service_unhealthy" {
  alarm_name = "${var.project_name}-service-unhealthy"
  alarm_description = "Multiple services are in unhealthy state"

  alarm_rule = <<EOF
ALARM("${aws_cloudwatch_metric_alarm.axon_cpu_high.alarm_name}") OR
ALARM("${aws_cloudwatch_metric_alarm.orbit_down.alarm_name}") OR
ALARM("${aws_cloudwatch_metric_alarm.governance_errors.alarm_name}")
EOF

  alarm_actions = [aws_sns_topic.alerts.arn]

  depends_on = [
    aws_cloudwatch_metric_alarm.axon_cpu_high,
    aws_cloudwatch_metric_alarm.orbit_down,
    aws_cloudwatch_metric_alarm.governance_errors
  ]
}
```

**Test Step 5.3:**

```bash
# Test SNS topic created
aws sns list-topics --query 'Topics[?contains(TopicArn, `alerts`)]'

# Test alarms created
aws cloudwatch describe-alarms --alarm-name-prefix "${PROJECT_NAME}"

# Test email subscription (check email for confirmation)
```

### Step 5.4: Tracing Setup (Optional) (1 hour)

**File: observability/terraform/xray.tf**

```hcl
# X-Ray sampling rule
resource "aws_xray_sampling_rule" "default" {
  rule_name      = "${var.project_name}-default"
  priority       = 100
  reservoir_size = 1
  fixed_rate     = 0.1
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"

  attributes = {
    rule_name = "${var.project_name}-default"
  }
}

# X-Ray group for service filtering
resource "aws_xray_group" "services" {
  group_name        = "${var.project_name}-services"
  filter_expression = "service(\"${var.project_name}-*\")"
}

# CloudWatch dashboard for X-Ray metrics
resource "aws_cloudwatch_dashboard" "xray" {
  dashboard_name = "${var.project_name}-xray-tracing"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x = 0
        y = 0
        width = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/XRay", "ResponseTime", "ServiceName", "${var.project_name}-axon", { "stat": "p95" }],
            [".", ".", ".", "${var.project_name}-orbit", { "stat": "p95" }],
            [".", ".", ".", "${var.project_name}-governance", { "stat": "p95" }]
          ]
          view = "timeSeries"
          stacked = false
          region = var.aws_region
          title = "X-Ray Response Times (p95)"
          period = 300
        }
      },
      {
        type = "metric"
        x = 12
        y = 0
        width = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/XRay", "ErrorRate", "ServiceName", "${var.project_name}-axon"],
            [".", ".", ".", "${var.project_name}-orbit"],
            [".", ".", ".", "${var.project_name}-governance"]
          ]
          view = "timeSeries"
          stacked = false
          region = var.aws_region
          title = "X-Ray Error Rates"
          period = 300
        }
      }
    ]
  })
}
```

**Test Step 5.4:**

```bash
# Enable X-Ray in services (requires service redeployment)
cd infra
terraform apply -target=module.observability

# Check X-Ray sampling rules
aws xray get-sampling-rules
```

### Step 5.5: Custom Metrics and Reporting (1 hour)

**File: observability/metrics/definitions.json**

```json
{
  "custom_metrics": [
    {
      "name": "RequestCount",
      "namespace": "${PROJECT_NAME}/API",
      "description": "Total API requests per service"
    },
    {
      "name": "SuccessRate",
      "namespace": "${PROJECT_NAME}/API",
      "description": "API success rate percentage"
    },
    {
      "name": "GovernanceDecisionTime",
      "namespace": "${PROJECT_NAME}/Governance",
      "description": "Time taken for governance decisions"
    },
    {
      "name": "InterServiceLatency",
      "namespace": "${PROJECT_NAME}/Network",
      "description": "Latency between services"
    }
  ],
  "sla_targets": {
    "availability": 99.9,
    "latency_p95": 500,
    "error_rate": 1.0
  }
}
```

**File: observability/scripts/metric-report.sh**

```bash
#!/bin/bash

# Generate weekly observability report

START_TIME=$(date -u -d '7 days ago' +%s)
END_TIME=$(date -u +%s)

echo "=== Observability Report ==="
echo "Period: $(date -d @$START_TIME) to $(date -d @$END_TIME)"
echo ""

echo "1. Service Health Metrics:"
echo "------------------------"

# CPU Utilization
echo "Average CPU Utilization (last 7 days):"
aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name CPUUtilization \
    --dimensions Name=ServiceName,Value=${PROJECT_NAME}-axon Name=ClusterName,Value=${PROJECT_NAME}-cluster \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --period 3600 \
    --statistics Average \
    --query 'Datapoints[*].[Timestamp,Average] | sort_by(@, &Timestamp)' \
    --output table

echo ""
echo "2. Error Analysis:"
echo "-----------------"

# Error count
aws cloudwatch get-metric-statistics \
    --namespace ${PROJECT_NAME}/Axon \
    --metric-name ErrorCount \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --period 3600 \
    --statistics Sum \
    --query 'Datapoints[*].[Timestamp,Sum] | sort_by(@, &Timestamp)' \
    --output table

echo ""
echo "3. Governance Decisions:"
echo "-----------------------"

# Governance calls
aws cloudwatch get-metric-statistics \
    --namespace ${PROJECT_NAME}/Governance \
    --metric-name DenialCount \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --period 3600 \
    --statistics Sum \
    --query 'Datapoints[*].[Timestamp,Sum] | sort_by(@, &Timestamp)' \
    --output table

echo ""
echo "4. SLA Compliance:"
echo "-----------------"

# Calculate SLA metrics
AVAILABILITY=$(aws cloudwatch get-metric-statistics \
    --namespace AWS/ECS \
    --metric-name RunningTaskCount \
    --dimensions Name=ServiceName,Value=${PROJECT_NAME}-axon Name=ClusterName,Value=${PROJECT_NAME}-cluster \
    --start-time $START_TIME \
    --end-time $END_TIME \
    --period 3600 \
    --statistics Average \
    --query 'Datapoints[?Average>=2] | length(@)' \
    --output text)

TOTAL_HOURS=168  # 7 days * 24 hours
UPTIME_PERCENTAGE=$(echo "scale=2; ($AVAILABILITY / $TOTAL_HOURS) * 100" | bc)

echo "Service Availability: ${UPTIME_PERCENTAGE}% (Target: 99.9%)"

if (( $(echo "$UPTIME_PERCENTAGE >= 99.9" | bc -l) )); then
    echo "✅ SLA Met"
else
    echo "❌ SLA Not Met"
fi

echo ""
echo "Report generated at: $(date)"
```

**Test Step 5.5:**

```bash
# Generate metric report
cd observability/scripts
./metric-report.sh

# Test custom metrics (if implemented in services)
aws cloudwatch list-metrics --namespace "${PROJECT_NAME}/API"
```

## Acceptance Criteria

- [ ] CloudWatch dashboards created and displaying data
- [ ] Structured JSON logs with correlation IDs
- [ ] CloudWatch Insights queries working
- [ ] SNS alerts configured and tested
- [ ] Log metric filters extracting custom metrics
- [ ] Log retention policies configured (30 days)
- [ ] Service health alarms active
- [ ] Error rate monitoring functional
- [ ] Governance decision tracking working
- [ ] Metric report script functional

## Rollback Procedure

If observability setup fails:

```bash
cd observability/terraform
terraform destroy -target=aws_cloudwatch_dashboard.main
terraform destroy -target=aws_cloudwatch_metric_alarm.axon_cpu_high
terraform destroy -target=aws_sns_topic.alerts
terraform destroy -target=aws_cloudwatch_log_group.axon
```

## Testing Script

Create `tasks/test-task-5.sh`:

```bash
#!/bin/bash
set -e

echo "Testing Task 5: Observability Setup"

# Test dashboards
DASHBOARD_COUNT=$(aws cloudwatch list-dashboards --query "DashboardEntries[?contains(DashboardName, \`${PROJECT_NAME}\`)] | length(@)")
if [ "$DASHBOARD_COUNT" -lt 3 ]; then
    echo "❌ Expected at least 3 dashboards, found $DASHBOARD_COUNT"
    exit 1
fi
echo "✅ CloudWatch dashboards created"

# Test log groups
AXON_LOGS=$(aws logs describe-log-groups --log-group-name "/ecs/${PROJECT_NAME}-axon" --query 'logGroups[0].logGroupName' 2>/dev/null || echo "")
if [ "$AXON_LOGS" != "/ecs/${PROJECT_NAME}-axon" ]; then
    echo "❌ Axon log group not found"
    exit 1
fi
echo "✅ CloudWatch log groups configured"

# Test SNS topic
TOPIC_ARN=$(aws sns list-topics --query "Topics[?contains(TopicArn, \`alerts\`)] | [0].TopicArn" --output text)
if [ -z "$TOPIC_ARN" ]; then
    echo "❌ SNS alerts topic not found"
    exit 1
fi
echo "✅ SNS alerts topic created"

# Test alarms
ALARM_COUNT=$(aws cloudwatch describe-alarms --alarm-name-prefix "${PROJECT_NAME}" --query 'length(MetricAlarms)')
if [ "$ALARM_COUNT" -lt 5 ]; then
    echo "❌ Expected at least 5 alarms, found $ALARM_COUNT"
    exit 1
fi
echo "✅ CloudWatch alarms configured"

# Test metric filters
FILTER_COUNT=$(aws logs describe-metric-filters --log-group-name "/ecs/${PROJECT_NAME}-axon" --query 'length(metricFilters)')
if [ "$FILTER_COUNT" -lt 1 ]; then
    echo "❌ Expected at least 1 metric filter for axon logs"
    exit 1
fi
echo "✅ Log metric filters configured"

# Test Insights queries
QUERY_COUNT=$(aws cloudwatch describe-insight-rules --query "InsightRules[?contains(Name, \`${PROJECT_NAME}\`)] | length(@)")
if [ "$QUERY_COUNT" -lt 2 ]; then
    echo "❌ Expected at least 2 Insights queries, found $QUERY_COUNT"
    exit 1
fi
echo "✅ CloudWatch Insights queries configured"

echo ""
echo "🎉 Task 5 Observability Setup: PASSED"
```
