variable "aws_region" {
  type        = string
  default     = "il-central-1"
  description = "Target AWS region for deploying the bootstrap resources."
}

variable "project" {
  type        = string
  default     = "compie"
  description = "Short lowercase project identifier used for resource naming and tagging."
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.project))
    error_message = "Project name must be 2-16 lowercase alphanumeric characters or hyphens."
  }
}

variable "github_subject" {
  type        = string
  description = "Exact GitHub Actions OIDC subject claim for repository and main branch (e.g. repo:Org/Repo:ref:refs/heads/main)."
  validation {
    condition     = endswith(var.github_subject, ":ref:refs/heads/main") && !strcontains(var.github_subject, "*")
    error_message = "Trust must be strictly scoped to the main branch with no wildcards."
  }
}

variable "existing_oidc_provider_arn" {
  type        = string
  default     = ""
  description = "ARN of an existing GitHub OIDC provider in the AWS account. Leave empty to let bootstrap create it."
}
