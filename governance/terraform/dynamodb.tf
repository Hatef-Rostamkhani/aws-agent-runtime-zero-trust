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

# Default policy: orbit:call_reasoning
resource "aws_dynamodb_table_item" "orbit_call_reasoning" {
  table_name = aws_dynamodb_table.policies.name
  hash_key   = aws_dynamodb_table.policies.hash_key
  range_key  = aws_dynamodb_table.policies.range_key

  item = jsonencode({
    service     = "orbit"
    intent      = "call_reasoning"
    enabled     = true
    description = "Allow Orbit to call Axon reasoning service"
    time_restrictions = {
      allowed_hours = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
    }
    rate_limits = {
      requests_per_minute = 100
      requests_per_hour   = 1000
    }
    conditions = []
  })
}

# Default policy: orbit:call_metrics
resource "aws_dynamodb_table_item" "orbit_call_metrics" {
  table_name = aws_dynamodb_table.policies.name
  hash_key   = aws_dynamodb_table.policies.hash_key
  range_key  = aws_dynamodb_table.policies.range_key

  item = jsonencode({
    service     = "orbit"
    intent      = "call_metrics"
    enabled     = true
    description = "Allow Orbit to retrieve metrics"
    time_restrictions = {
      allowed_hours = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23]
    }
    rate_limits = {
      requests_per_minute = 60
      requests_per_hour   = 500
    }
    conditions = []
  })
}

