# State and image registry

output "state_bucket" {
  description = "Name of the remote S3 state bucket."
  value       = aws_s3_bucket.state.id
}

output "ecr_repository_url" {
  description = "URL of the application ECR repository."
  value       = aws_ecr_repository.app.repository_url
}

# Runtime configuration

output "app_config_secret_arn" {
  description = "ARN of the Secrets Manager secret for runtime configuration."
  value       = aws_secretsmanager_secret.app.arn
}

output "release_parameter" {
  description = "SSM parameter storing the deployed ECR image digest."
  value       = aws_ssm_parameter.release.name
}

# CI identities

output "application_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions for application CI/CD."
  value       = aws_iam_role.application_ci.arn
}

output "infrastructure_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions for infrastructure Terraform automation."
  value       = aws_iam_role.infrastructure_ci.arn
}
