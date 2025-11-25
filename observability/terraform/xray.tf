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
  version        = 1
  resource_arn   = "*"

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
