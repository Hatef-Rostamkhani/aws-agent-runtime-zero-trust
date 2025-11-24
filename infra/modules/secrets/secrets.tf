resource "aws_secretsmanager_secret" "axon" {
  name                    = "${var.project_name}/axon"
  description             = "Secrets for Axon service"
  kms_key_id              = var.axon_kms_key_id
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-axon-secret"
  }
}

resource "aws_secretsmanager_secret_version" "axon" {
  secret_id = aws_secretsmanager_secret.axon.id
  secret_string = jsonencode({
    database_url = "placeholder"
    api_key      = "placeholder"
  })
}

resource "aws_secretsmanager_secret" "orbit" {
  name                    = "${var.project_name}/orbit"
  description             = "Secrets for Orbit service"
  kms_key_id              = var.orbit_kms_key_id
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-orbit-secret"
  }
}

resource "aws_secretsmanager_secret_version" "orbit" {
  secret_id = aws_secretsmanager_secret.orbit.id
  secret_string = jsonencode({
    database_url = "placeholder"
    api_key      = "placeholder"
  })
}

