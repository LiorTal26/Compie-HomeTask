terraform {
  required_version = "= 1.13.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "= 6.21.0" }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = { Project = var.project, Environment = "dev", ManagedBy = "Terraform" } }
}

variable "aws_region" { default = "il-central-1" }
variable "project" {
  default = "compie"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.project))
    error_message = "Use a short lowercase project name."
  }
}
variable "github_subject" {
  type        = string
  description = "Exact GitHub OIDC sub for the repository and main branch. Match the repository's actual subject format."
  validation {
    condition     = endswith(var.github_subject, ":ref:refs/heads/main") && !strcontains(var.github_subject, "*")
    error_message = "Trust must be restricted to the main branch with no wildcard."
  }
}
variable "existing_oidc_provider_arn" {
  type        = string
  default     = ""
  description = "Reuse an existing token.actions.githubusercontent.com provider if the account already has one."
}

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
  ci_trust = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow", Principal = { Federated = local.oidc_arn },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = { StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub" = var.github_subject
      } }
    }]
  })
}

resource "aws_s3_bucket" "state" {
  bucket        = local.state_bucket
  force_destroy = true # Dedicated disposable assignment bucket; destroy removes old state versions.
}
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Sid       = "RequireTLS", Effect = "Deny", Principal = "*", Action = "s3:*",
      Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"],
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_ecr_repository" "app" {
  name                 = local.prefix
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # Only this assignment repository.
  image_scanning_configuration { scan_on_push = true }
}

# Metadata only. A local bootstrap command supplies the configuration value.
resource "aws_secretsmanager_secret" "app" {
  name                    = "/${var.project}/dev/app-config"
  description             = "Runtime configuration; CI may inspect metadata but cannot retrieve values."
  recovery_window_in_days = 0
  # Omitting kms_key_id selects the AWS-managed aws/secretsmanager key.
}

resource "aws_ssm_parameter" "release" {
  name  = local.release_name
  type  = "String"
  value = "UNINITIALIZED"
  lifecycle { ignore_changes = [value] }
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.existing_oidc_provider_arn == "" ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # IAM validates GitHub's certificate using its trusted CA list.
}

resource "aws_iam_role" "instance" {
  name = "${local.prefix}-instance"
  assume_role_policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_instance_profile" "app" {
  name = "${local.prefix}-instance"
  role = aws_iam_role.instance.name
}
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy" "runtime" {
  role = aws_iam_role.instance.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"], Resource = aws_ecr_repository.app.arn },
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = aws_secretsmanager_secret.app.arn },
      { Effect = "Allow", Action = ["dynamodb:Query", "dynamodb:PutItem", "dynamodb:DeleteItem"], Resource = local.table_arn },
      { Effect = "Allow", Action = ["ssm:GetParameter"], Resource = local.release_arn },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = [local.log_arn, "${local.log_arn}:*"] },
      { Effect = "Allow", Action = ["logs:DescribeLogGroups"], Resource = "*", Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region } } }
    ]
  })
}

resource "aws_iam_role" "application_ci" {
  name               = "${local.prefix}-application-ci"
  assume_role_policy = local.ci_trust
}
resource "aws_iam_role_policy" "application_ci" {
  role = aws_iam_role.application_ci.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      { Effect = "Deny", Action = ["secretsmanager:GetSecretValue", "secretsmanager:BatchGetSecretValue"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:DescribeImages", "ecr:BatchGetImage"], Resource = aws_ecr_repository.app.arn },
      { Effect = "Allow", Action = ["ssm:GetParameter", "ssm:PutParameter"], Resource = local.release_arn },
      { Effect = "Allow", Action = ["autoscaling:StartInstanceRefresh", "autoscaling:CancelInstanceRefresh"], Resource = local.asg_arn },
      { Effect = "Allow", Action = ["autoscaling:DescribeAutoScalingGroups", "autoscaling:DescribeInstanceRefreshes", "autoscaling:DescribeScalingActivities", "elasticloadbalancing:DescribeTargetHealth"], Resource = "*" }
    ]
  })
}

resource "aws_iam_role" "infrastructure_ci" {
  name               = "${local.prefix}-infrastructure-ci"
  assume_role_policy = local.ci_trust
}
resource "aws_iam_role_policy" "infrastructure_ci" {
  role = aws_iam_role.infrastructure_ci.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      { Sid = "NeverReadApplicationSecrets", Effect = "Deny", Action = ["secretsmanager:GetSecretValue", "secretsmanager:BatchGetSecretValue"], Resource = "*" },
      { Sid = "StateBucket", Effect = "Allow", Action = ["s3:ListBucket", "s3:GetBucketLocation"], Resource = aws_s3_bucket.state.arn },
      { Sid = "DevState", Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject"], Resource = "${aws_s3_bucket.state.arn}/dev/terraform.tfstate" },
      { Sid = "StateLock", Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.state.arn}/dev/terraform.tfstate.tflock" },
      { Sid = "InstanceProfile", Effect = "Allow", Action = ["iam:PassRole"], Resource = aws_iam_role.instance.arn, Condition = { StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" } } },
      { Sid = "ServiceLinkedRoles", Effect = "Allow", Action = ["iam:CreateServiceLinkedRole"], Resource = "arn:aws:iam::${local.account}:role/aws-service-role/*", Condition = { StringEquals = { "iam:AWSServiceName" = ["autoscaling.amazonaws.com", "elasticloadbalancing.amazonaws.com"] } } },
      { Sid = "ConfigMetadata", Effect = "Allow", Action = ["secretsmanager:DescribeSecret"], Resource = aws_secretsmanager_secret.app.arn },
      { Sid = "PublicAMI", Effect = "Allow", Action = ["ssm:GetParameter"], Resource = "arn:aws:ssm:${var.aws_region}::parameter/aws/service/ami-amazon-linux-latest/*" },
      { Sid = "DescribeCompute", Effect = "Allow", Action = ["ec2:Describe*", "elasticloadbalancing:Describe*", "autoscaling:Describe*"], Resource = "*", Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region } } },
      { Sid = "VPCAndLaunchTemplate", Effect = "Allow", Action = [
        "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute", "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
        "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway", "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
        "ec2:CreateRouteTable", "ec2:DeleteRouteTable", "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
        "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:ReplaceRoute", "ec2:AllocateAddress", "ec2:ReleaseAddress",
        "ec2:CreateNatGateway", "ec2:DeleteNatGateway", "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress", "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupIngress", "ec2:RevokeSecurityGroupEgress",
        "ec2:ModifySecurityGroupRules", "ec2:CreateVpcEndpoint", "ec2:ModifyVpcEndpoint", "ec2:DeleteVpcEndpoints",
        "ec2:CreateLaunchTemplate", "ec2:CreateLaunchTemplateVersion", "ec2:ModifyLaunchTemplate", "ec2:DeleteLaunchTemplate", "ec2:DeleteLaunchTemplateVersions",
        "ec2:CreateTags", "ec2:DeleteTags", "ec2:RunInstances"
      ], Resource = "*", Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region } } },
      { Sid = "LoadBalancer", Effect = "Allow", Action = [
        "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:DeleteLoadBalancer", "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup", "elasticloadbalancing:ModifyTargetGroup", "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener", "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:AddTags", "elasticloadbalancing:RemoveTags", "elasticloadbalancing:SetSecurityGroups", "elasticloadbalancing:SetSubnets"
      ], Resource = "*", Condition = { StringEquals = { "aws:RequestedRegion" = var.aws_region } } },
      { Sid = "AutoScaling", Effect = "Allow", Action = [
        "autoscaling:CreateAutoScalingGroup", "autoscaling:UpdateAutoScalingGroup", "autoscaling:DeleteAutoScalingGroup", "autoscaling:CreateOrUpdateTags", "autoscaling:DeleteTags",
        "autoscaling:AttachLoadBalancerTargetGroups", "autoscaling:DetachLoadBalancerTargetGroups", "autoscaling:StartInstanceRefresh", "autoscaling:CancelInstanceRefresh"
      ], Resource = local.asg_arn },
      { Sid = "TableManagement", Effect = "Allow", Action = [
        "dynamodb:CreateTable", "dynamodb:DeleteTable", "dynamodb:UpdateTable", "dynamodb:DescribeTable", "dynamodb:DescribeContinuousBackups", "dynamodb:DescribeTimeToLive",
        "dynamodb:ListTagsOfResource", "dynamodb:TagResource", "dynamodb:UntagResource", "dynamodb:PutResourcePolicy", "dynamodb:GetResourcePolicy", "dynamodb:DeleteResourcePolicy"
      ], Resource = local.table_arn },
      { Sid = "Logs", Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy", "logs:ListTagsForResource", "logs:TagResource", "logs:UntagResource"], Resource = [local.log_arn, "${local.log_arn}:*"] },
      { Sid = "DescribeLogs", Effect = "Allow", Action = ["logs:DescribeLogGroups"], Resource = "*" },
      { Sid = "Alarms", Effect = "Allow", Action = ["cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:DescribeAlarms", "cloudwatch:ListTagsForResource", "cloudwatch:TagResource", "cloudwatch:UntagResource"], Resource = "arn:aws:cloudwatch:${var.aws_region}:${local.account}:alarm:${local.prefix}-*" },
      { Sid = "Topic", Effect = "Allow", Action = ["sns:CreateTopic", "sns:DeleteTopic", "sns:GetTopicAttributes", "sns:SetTopicAttributes", "sns:ListTagsForResource", "sns:TagResource", "sns:UntagResource", "sns:Subscribe", "sns:Unsubscribe", "sns:GetSubscriptionAttributes", "sns:SetSubscriptionAttributes"], Resource = "arn:aws:sns:${var.aws_region}:${local.account}:${local.prefix}-alerts*" },
      { Sid = "AlertQueue", Effect = "Allow", Action = ["sqs:CreateQueue", "sqs:DeleteQueue", "sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:SetQueueAttributes", "sqs:ListQueueTags", "sqs:TagQueue", "sqs:UntagQueue"], Resource = "arn:aws:sqs:${var.aws_region}:${local.account}:${local.prefix}-alerts" }
    ]
  })
}

output "state_bucket" { value = aws_s3_bucket.state.id }
output "ecr_repository_url" { value = aws_ecr_repository.app.repository_url }
output "app_config_secret_arn" { value = aws_secretsmanager_secret.app.arn }
output "release_parameter" { value = aws_ssm_parameter.release.name }
output "application_role_arn" { value = aws_iam_role.application_ci.arn }
output "infrastructure_role_arn" { value = aws_iam_role.infrastructure_ci.arn }
