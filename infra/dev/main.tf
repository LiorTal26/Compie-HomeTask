terraform {
  required_version = "= 1.13.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "= 6.21.0" }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = { Project = var.project, Environment = "dev", ManagedBy = "Terraform" } }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" { state = "available" }
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
data "aws_secretsmanager_secret" "app" { name = "/${var.project}/dev/app-config" }

locals {
  https_enabled = var.domain_name != ""
  prefix        = "${var.project}-dev"
  account       = data.aws_caller_identity.current.account_id
  zones         = slice(data.aws_availability_zones.available.names, 0, 2)
  app_role_arn  = "arn:aws:iam::${local.account}:role/${local.prefix}-instance"
  table_name    = "${local.prefix}-items"
  release_name  = "/${var.project}/dev/release-image"
  ecr_registry  = "${local.account}.dkr.ecr.${var.aws_region}.amazonaws.com"
  ecr_repo      = "${local.ecr_registry}/${local.prefix}"
  # Restrict data operations, including alternate read/write APIs, while retaining Terraform's control-plane access.
  data_actions = [
    "dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:Query", "dynamodb:Scan",
    "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:BatchWriteItem",
    "dynamodb:ConditionCheckItem", "dynamodb:PartiQLSelect", "dynamodb:PartiQLInsert", "dynamodb:PartiQLUpdate", "dynamodb:PartiQLDelete"
  ]
}
