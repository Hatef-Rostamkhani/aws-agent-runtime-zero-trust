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