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
