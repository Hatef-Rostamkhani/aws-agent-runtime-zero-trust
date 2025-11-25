# CloudWatch Log Groups (data sources for existing groups created by ECS/Lambda)
data "aws_cloudwatch_log_group" "axon" {
  name = "/ecs/${var.project_name}-axon"
}

data "aws_cloudwatch_log_group" "orbit" {
  name = "/ecs/${var.project_name}-orbit"
}

data "aws_cloudwatch_log_group" "governance" {
  name = "/aws/lambda/${var.project_name}-governance"
}

# Log Metric Filters for custom metrics
resource "aws_cloudwatch_log_metric_filter" "axon_errors" {
  name           = "${var.project_name}-axon-errors"
  pattern        = "\"level\":\"ERROR\""
  log_group_name = data.aws_cloudwatch_log_group.axon.name

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
  log_group_name = data.aws_cloudwatch_log_group.orbit.name

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
  log_group_name = data.aws_cloudwatch_log_group.governance.name

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
    data.aws_cloudwatch_log_group.axon.name,
    data.aws_cloudwatch_log_group.orbit.name,
    data.aws_cloudwatch_log_group.governance.name
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
    data.aws_cloudwatch_log_group.orbit.name,
    data.aws_cloudwatch_log_group.governance.name,
    data.aws_cloudwatch_log_group.axon.name
  ]

  query_string = <<EOF
fields @timestamp, @message, correlation_id, service, operation
| filter ispresent(correlation_id)
| sort @timestamp desc, correlation_id
| limit 100
EOF
}
