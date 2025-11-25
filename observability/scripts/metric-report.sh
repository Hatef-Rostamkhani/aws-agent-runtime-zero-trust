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
