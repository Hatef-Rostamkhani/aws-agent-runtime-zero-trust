#!/bin/bash

# Test alerting setup

set -e

echo "Testing alerting setup..."

# Test SNS topic
echo "Checking SNS topic..."
TOPIC_ARN=$(aws sns list-topics --query "Topics[?contains(TopicArn, \`alerts\`)] | [0].TopicArn" --output text)
if [ -z "$TOPIC_ARN" ]; then
    echo "❌ SNS alerts topic not found"
    exit 1
fi
echo "✅ SNS alerts topic exists: $TOPIC_ARN"

# Test alarms
echo "Checking CloudWatch alarms..."
ALARM_COUNT=$(aws cloudwatch describe-alarms --alarm-name-prefix "${PROJECT_NAME}" --query 'length(MetricAlarms)')
if [ "$ALARM_COUNT" -lt 5 ]; then
    echo "❌ Expected at least 5 alarms, found $ALARM_COUNT"
    exit 1
fi
echo "✅ Found $ALARM_COUNT CloudWatch alarms"

# List alarms
echo "Current alarms:"
aws cloudwatch describe-alarms --alarm-name-prefix "${PROJECT_NAME}" --query 'MetricAlarms[*].[AlarmName,StateValue,StateReason]' --output table

# Test email subscription (if configured)
SUBSCRIPTIONS=$(aws sns list-subscriptions-by-topic --topic-arn "$TOPIC_ARN" --query 'Subscriptions[*].[Protocol,Endpoint]' --output text)
if [ -n "$SUBSCRIPTIONS" ]; then
    echo "✅ Email subscriptions configured:"
    echo "$SUBSCRIPTIONS"
else
    echo "ℹ️  No email subscriptions configured (consider adding one for testing)"
fi

echo "🎉 Alerting setup test completed"
