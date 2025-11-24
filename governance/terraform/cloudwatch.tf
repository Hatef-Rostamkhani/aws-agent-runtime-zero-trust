resource "aws_cloudwatch_log_group" "governance" {
  name              = "/aws/lambda/${var.project_name}-governance"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-governance-logs"
    Service     = "governance"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "governance_errors" {
  alarm_name          = "${var.project_name}-governance-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Governance Lambda has errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.governance.function_name
  }

  tags = {
    Name        = "${var.project_name}-governance-errors-alarm"
    Service     = "governance"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "governance_duration" {
  alarm_name          = "${var.project_name}-governance-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 5000
  alarm_description   = "Governance Lambda duration > 5s"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.governance.function_name
  }

  tags = {
    Name        = "${var.project_name}-governance-duration-alarm"
    Service     = "governance"
    Environment = var.environment
  }
}

