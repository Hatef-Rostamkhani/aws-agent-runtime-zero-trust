resource "aws_dynamodb_table" "policies" {
  name         = "${var.project_name}-governance-policies"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "service"
  range_key    = "intent"

  attribute {
    name = "service"
    type = "S"
  }

  attribute {
    name = "intent"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-governance-policies"
    Service     = "governance"
    Environment = var.environment
  }
}

# Read default policies from JSON file
locals {
  default_policies = jsondecode(file("${path.module}/../policies/default.json"))
}

# Create DynamoDB items for each default policy
resource "aws_dynamodb_table_item" "policies" {
  for_each = { for idx, policy in local.default_policies : "${policy.service}:${policy.intent}" => policy }

  table_name = aws_dynamodb_table.policies.name
  hash_key   = aws_dynamodb_table.policies.hash_key
  range_key  = aws_dynamodb_table.policies.range_key

  # Build item dynamically to handle null values properly
  item = jsonencode(merge({
    service     = { S = each.value.service }
    intent      = { S = each.value.intent }
    enabled     = { BOOL = each.value.enabled }
    description = { S = each.value.description }
    rate_limits = {
      M = {
        requests_per_minute = { N = tostring(each.value.rate_limits.requests_per_minute) }
        requests_per_hour   = { N = tostring(each.value.rate_limits.requests_per_hour) }
      }
    }
    conditions = { L = each.value.conditions }
    }, each.value.time_restrictions != null ? {
    time_restrictions = {
      M = {
        allowed_hours = {
          L = [for hour in each.value.time_restrictions.allowed_hours : { N = tostring(hour) }]
        }
      }
    }
  } : {}))
}

