resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-main-dashboard"

  dashboard_body = templatefile("${path.module}/../dashboards/main-dashboard.json", {
    PROJECT_NAME = var.project_name
    AWS_REGION   = var.aws_region
  })
}

resource "aws_cloudwatch_dashboard" "service_health" {
  dashboard_name = "${var.project_name}-service-health"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        x = 0
        y = 0
        width = 24
        height = 8
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "${var.project_name}-axon", "ClusterName", "${var.project_name}-cluster", { "stat": "Maximum", "label": "Axon CPU Max" }],
            [".", ".", ".", "${var.project_name}-orbit", ".", ".", { "stat": "Maximum", "label": "Orbit CPU Max" }],
            [".", ".", ".", "${var.project_name}-axon", ".", ".", { "stat": "Average", "label": "Axon CPU Avg" }],
            [".", ".", ".", "${var.project_name}-orbit", ".", ".", { "stat": "Average", "label": "Orbit CPU Avg" }]
          ]
          view = "timeSeries"
          stacked = false
          region = var.aws_region
          title = "Service CPU Utilization"
          period = 300
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "governance" {
  dashboard_name = "${var.project_name}-governance"

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
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.project_name}-governance"]
          ]
          view = "timeSeries"
          stacked = false
          region = var.aws_region
          title = "Governance Invocations"
          period = 300
          stat = "Sum"
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
            ["AWS/Lambda", "Duration", "FunctionName", "${var.project_name}-governance", { "stat": "p95" }],
            [".", ".", ".", ".", { "stat": "p99" }]
          ]
          view = "timeSeries"
          stacked = false
          region = var.aws_region
          title = "Governance Latency (p95/p99)"
          period = 300
        }
      },
      {
        type = "log"
        x = 0
        y = 6
        width = 24
        height = 6
        properties = {
          query = "fields @timestamp, service, intent, allowed, reason, correlation_id\n| filter ispresent(allowed)\n| sort @timestamp desc\n| limit 50"
          region = var.aws_region
          title = "Recent Governance Decisions"
          view = "table"
        }
      }
    ]
  })
}
