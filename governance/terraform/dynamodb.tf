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
    service = { S = "orbit" }
    intent  = { S = "call_reasoning" }
    enabled = { BOOL = true }
    description = { S = "Allow Orbit to call Axon reasoning service" }
    time_restrictions = {
      M = {
        allowed_hours = {
          L = [
            { N = "0" }, { N = "1" }, { N = "2" }, { N = "3" }, { N = "4" }, { N = "5" },
            { N = "6" }, { N = "7" }, { N = "8" }, { N = "9" }, { N = "10" }, { N = "11" },
            { N = "12" }, { N = "13" }, { N = "14" }, { N = "15" }, { N = "16" }, { N = "17" },
            { N = "18" }, { N = "19" }, { N = "20" }, { N = "21" }, { N = "22" }, { N = "23" }
          ]
        }
      }
    }
    rate_limits = {
      M = {
        requests_per_minute = { N = "100" }
        requests_per_hour   = { N = "1000" }
      }
    }
    conditions = { L = [] }
  })
}

# Default policy: orbit:call_metrics
resource "aws_dynamodb_table_item" "orbit_call_metrics" {
  table_name = aws_dynamodb_table.policies.name
  hash_key   = aws_dynamodb_table.policies.hash_key
  range_key  = aws_dynamodb_table.policies.range_key

  item = jsonencode({
    service = { S = "orbit" }
    intent  = { S = "call_metrics" }
    enabled = { BOOL = true }
    description = { S = "Allow Orbit to retrieve metrics" }
    time_restrictions = {
      M = {
        allowed_hours = {
          L = [
            { N = "0" }, { N = "1" }, { N = "2" }, { N = "3" }, { N = "4" }, { N = "5" },
            { N = "6" }, { N = "7" }, { N = "8" }, { N = "9" }, { N = "10" }, { N = "11" },
            { N = "12" }, { N = "13" }, { N = "14" }, { N = "15" }, { N = "16" }, { N = "17" },
            { N = "18" }, { N = "19" }, { N = "20" }, { N = "21" }, { N = "22" }, { N = "23" }
          ]
        }
      }
    }
    rate_limits = {
      M = {
        requests_per_minute = { N = "60" }
        requests_per_hour   = { N = "500" }
      }
    }
    conditions = { L = [] }
  })
}

