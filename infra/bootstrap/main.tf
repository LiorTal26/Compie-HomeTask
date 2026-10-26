# Terraform and AWS provider

terraform {
  required_version = "= 1.13.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws",
      version = "= 6.21.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project,
      Environment = "dev",
      ManagedBy   = "Terraform"
    }
  }
}

# Account and shared naming

data "aws_caller_identity" "current" {}

locals {
  prefix       = "${var.project}-dev"
  account      = data.aws_caller_identity.current.account_id
  state_bucket = "${local.prefix}-tfstate-${local.account}-${var.aws_region}"
  table_arn    = "arn:aws:dynamodb:${var.aws_region}:${local.account}:table/${local.prefix}-items"
  asg_arn      = "arn:aws:autoscaling:${var.aws_region}:${local.account}:autoScalingGroup:*:autoScalingGroupName/${local.prefix}-asg"
  release_name = "/${var.project}/dev/release-image"
  release_arn  = "arn:aws:ssm:${var.aws_region}:${local.account}:parameter${local.release_name}"
  log_arn      = "arn:aws:logs:${var.aws_region}:${local.account}:log-group:/${var.project}/dev/*"
  oidc_arn     = var.existing_oidc_provider_arn != "" ? var.existing_oidc_provider_arn : aws_iam_openid_connect_provider.github[0].arn

  # GitHub OIDC trust
  ci_trust = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = local.oidc_arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub" = var.github_subject
        }
      }
    }]
  })
}
