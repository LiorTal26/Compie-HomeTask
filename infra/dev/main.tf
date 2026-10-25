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

variable "aws_region" { default = "il-central-1" }
variable "project" { default = "compie" }
variable "instance_type" { default = "t3.micro" }

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" { state = "available" }
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
data "aws_secretsmanager_secret" "app" { name = "/${var.project}/dev/app-config" }

locals {
  prefix       = "${var.project}-dev"
  account      = data.aws_caller_identity.current.account_id
  zones        = slice(data.aws_availability_zones.available.names, 0, 2)
  app_role_arn = "arn:aws:iam::${local.account}:role/${local.prefix}-instance"
  table_name   = "${local.prefix}-items"
  release_name = "/${var.project}/dev/release-image"
  ecr_registry = "${local.account}.dkr.ecr.${var.aws_region}.amazonaws.com"
  ecr_repo     = "${local.ecr_registry}/${local.prefix}"
  # Restrict data operations, including alternate read/write APIs, while retaining Terraform's control-plane access.
  data_actions = [
    "dynamodb:GetItem", "dynamodb:BatchGetItem", "dynamodb:Query", "dynamodb:Scan",
    "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:BatchWriteItem",
    "dynamodb:ConditionCheckItem", "dynamodb:PartiQLSelect", "dynamodb:PartiQLInsert", "dynamodb:PartiQLUpdate", "dynamodb:PartiQLDelete"
  ]
}

output "application_url" { value = "http://${aws_lb.app.dns_name}" }
output "asg_name" { value = aws_autoscaling_group.app.name }
output "target_group_arn" { value = aws_lb_target_group.app.arn }
output "database_table" { value = aws_dynamodb_table.items.name }
output "dynamodb_endpoint_id" { value = aws_vpc_endpoint.dynamodb.id }
output "alarm_name" { value = aws_cloudwatch_metric_alarm.no_healthy_targets.alarm_name }
output "alert_queue_url" { value = aws_sqs_queue.alerts.url }
output "application_log_group" { value = aws_cloudwatch_log_group.app.name }
output "instance_log_group" { value = aws_cloudwatch_log_group.instance.name }
output "dashboard_name" { value = aws_cloudwatch_dashboard.app.dashboard_name }
