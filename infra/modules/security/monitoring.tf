# CloudWatch Alarms for Security Events

# Alarm for unauthorized API calls
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "${var.project_name}-unauthorized-api-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedAttemptCount"
  namespace           = "AWS/CloudTrail"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Unauthorized API calls detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = {
    Name = "${var.project_name}-unauthorized-api-alarm"
  }
}

# Alarm for security group changes
resource "aws_cloudwatch_metric_alarm" "security_group_changes" {
  alarm_name          = "${var.project_name}-security-group-changes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SecurityGroupEventCount"
  namespace           = "AWS/CloudTrail"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Security group configuration changes detected"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = {
    Name = "${var.project_name}-security-group-alarm"
  }
}

# Alarm for IAM policy changes
resource "aws_cloudwatch_metric_alarm" "iam_policy_changes" {
  alarm_name          = "${var.project_name}-iam-policy-changes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name = "PolicyEventCount"
  namespace   = "AWS/CloudTrail"
  period      = "300"
  statistic   = "Sum"
  threshold   = "0"
  alarm_description = "IAM policy changes detected"
  alarm_actions     = [aws_sns_topic.security_alerts.arn]

  tags = {
    Name = "${var.project_name}-iam-policy-alarm"
  }
}

# SNS Topic for security alerts
resource "aws_sns_topic" "security_alerts" {
  name = "${var.project_name}-security-alerts"

  tags = {
    Name = "${var.project_name}-security-alerts"
  }
}

# CloudWatch Log Groups for security logging
resource "aws_cloudwatch_log_group" "security_events" {
  name              = "/aws/security/${var.project_name}"
  retention_in_days = 365

  tags = {
    Name = "${var.project_name}-security-events"
  }
}

# CloudWatch Dashboard for security monitoring
resource "aws_cloudwatch_dashboard" "security" {
  dashboard_name = "${var.project_name}-security-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/CloudTrail", "UnauthorizedAttemptCount", { "stat": "Sum" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Unauthorized API Calls"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/CloudTrail", "SecurityGroupEventCount", { "stat": "Sum" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Security Group Changes"
          period  = 300
        }
      }
    ]
  })
}
