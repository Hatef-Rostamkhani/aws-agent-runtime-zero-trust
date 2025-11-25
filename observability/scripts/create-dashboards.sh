#!/bin/bash

# Create CloudWatch dashboards from JSON templates

set -e

echo "Creating CloudWatch dashboards..."

# Main dashboard
aws cloudwatch put-dashboard \
    --dashboard-name "${PROJECT_NAME}-main-dashboard" \
    --dashboard-body file://observability/dashboards/main-dashboard.json

echo "✅ Main dashboard created"

# Service health dashboard
SERVICE_HEALTH_BODY=$(cat <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 24,
      "height": 8,
      "properties": {
        "metrics": [
          ["AWS/ECS", "CPUUtilization", "ServiceName", "${PROJECT_NAME}-axon", "ClusterName", "${PROJECT_NAME}-cluster", { "stat": "Maximum", "label": "Axon CPU Max" }],
          [".", ".", ".", "${PROJECT_NAME}-orbit", ".", ".", { "stat": "Maximum", "label": "Orbit CPU Max" }],
          [".", ".", ".", "${PROJECT_NAME}-axon", ".", ".", { "stat": "Average", "label": "Axon CPU Avg" }],
          [".", ".", ".", "${PROJECT_NAME}-orbit", ".", ".", { "stat": "Average", "label": "Orbit CPU Avg" }]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "title": "Service CPU Utilization",
        "period": 300
      }
    }
  ]
}
EOF
)

aws cloudwatch put-dashboard \
    --dashboard-name "${PROJECT_NAME}-service-health" \
    --dashboard-body "$SERVICE_HEALTH_BODY"

echo "✅ Service health dashboard created"

# Governance dashboard
GOVERNANCE_BODY=$(cat <<EOF
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
          ["AWS/Lambda", "Invocations", "FunctionName", "${PROJECT_NAME}-governance"]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "title": "Governance Invocations",
        "period": 300,
        "stat": "Sum"
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
          ["AWS/Lambda", "Duration", "FunctionName", "${PROJECT_NAME}-governance", { "stat": "p95" }],
          [".", ".", ".", ".", { "stat": "p99" }]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${AWS_REGION}",
        "title": "Governance Latency (p95/p99)",
        "period": 300
      }
    },
    {
      "type": "log",
      "x": 0,
      "y": 6,
      "width": 24,
      "height": 6,
      "properties": {
        "query": "fields @timestamp, service, intent, allowed, reason, correlation_id\\n| filter ispresent(allowed)\\n| sort @timestamp desc\\n| limit 50",
        "region": "${AWS_REGION}",
        "title": "Recent Governance Decisions",
        "view": "table"
      }
    }
  ]
}
EOF
)

aws cloudwatch put-dashboard \
    --dashboard-name "${PROJECT_NAME}-governance" \
    --dashboard-body "$GOVERNANCE_BODY"

echo "✅ Governance dashboard created"

echo "🎉 All dashboards created successfully"
