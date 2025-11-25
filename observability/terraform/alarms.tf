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
  statistic           = "Average"
  threshold           = "1000"
  alarm_description   = "Governance Lambda average latency > 1s"
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

  alarm_rule = "ALARM(\"${var.project_name}-axon-cpu-high\") OR ALARM(\"${var.project_name}-orbit-service-down\") OR ALARM(\"${var.project_name}-governance-errors\")"

  alarm_actions = [aws_sns_topic.alerts.arn]

  depends_on = [
    aws_cloudwatch_metric_alarm.axon_cpu_high,
    aws_cloudwatch_metric_alarm.orbit_down,
    aws_cloudwatch_metric_alarm.governance_errors
  ]
}
