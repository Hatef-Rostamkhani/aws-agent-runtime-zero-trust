output "github_oidc_provider_arn" {
  description = "GitHub OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_app_role_arn" {
  description = "GitHub Actions application deployment role ARN"
  value       = var.github_org != "" && var.github_repo != "" ? aws_iam_role.github_actions_app[0].arn : ""
}

output "github_actions_infra_role_arn" {
  description = "GitHub Actions infrastructure deployment role ARN"
  value       = var.github_org != "" && var.github_repo != "" ? aws_iam_role.github_actions_infra[0].arn : ""
}

