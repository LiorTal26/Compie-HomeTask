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
    Version = "2012-10-17", Statement = concat([
      { Sid = "NeverReadApplicationSecrets", Effect = "Deny", Action = ["secretsmanager:GetSecretValue", "secretsmanager:BatchGetSecretValue"], Resource = "*" },
      { Sid = "StateBucket", Effect = "Allow", Action = ["s3:ListBucket", "s3:GetBucketLocation"], Resource = aws_s3_bucket.state.arn },
      { Sid = "DevState", Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject"], Resource = "${aws_s3_bucket.state.arn}/dev/terraform.tfstate" },
      { Sid = "StateLock", Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.state.arn}/dev/terraform.tfstate.tflock" },
      { Sid = "InstanceProfile", Effect = "Allow", Action = ["iam:PassRole"], Resource = aws_iam_role.instance.arn, Condition = { StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" } } },
      { Sid = "ServiceLinkedRoles", Effect = "Allow", Action = ["iam:CreateServiceLinkedRole"], Resource = "arn:aws:iam::${local.account}:role/aws-service-role/*", Condition = { StringEquals = { "iam:AWSServiceName" = ["autoscaling.amazonaws.com", "elasticloadbalancing.amazonaws.com"] } } },
      { Sid = "ConfigMetadata", Effect = "Allow", Action = ["secretsmanager:DescribeSecret", "secretsmanager:GetResourcePolicy"], Resource = aws_secretsmanager_secret.app.arn },
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
        "autoscaling:AttachLoadBalancerTargetGroups", "autoscaling:DetachLoadBalancerTargetGroups", "autoscaling:StartInstanceRefresh", "autoscaling:CancelInstanceRefresh",
        "autoscaling:PutScalingPolicy", "autoscaling:DeletePolicy"
      ], Resource = local.asg_arn },
      { Sid = "TableManagement", Effect = "Allow", Action = [
        "dynamodb:CreateTable", "dynamodb:DeleteTable", "dynamodb:UpdateTable", "dynamodb:DescribeTable", "dynamodb:DescribeContinuousBackups", "dynamodb:DescribeTimeToLive",
        "dynamodb:ListTagsOfResource", "dynamodb:TagResource", "dynamodb:UntagResource", "dynamodb:PutResourcePolicy", "dynamodb:GetResourcePolicy", "dynamodb:DeleteResourcePolicy"
      ], Resource = local.table_arn },
      { Sid = "Logs", Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy", "logs:ListTagsForResource", "logs:TagResource", "logs:UntagResource"], Resource = [local.log_arn, "${local.log_arn}:*"] },
      { Sid = "DescribeLogs", Effect = "Allow", Action = ["logs:DescribeLogGroups"], Resource = "*" },
      { Sid = "Alarms", Effect = "Allow", Action = ["cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:DescribeAlarms", "cloudwatch:ListTagsForResource", "cloudwatch:TagResource", "cloudwatch:UntagResource"], Resource = "arn:aws:cloudwatch:${var.aws_region}:${local.account}:alarm:${local.prefix}-*" },
      { Sid = "Dashboard", Effect = "Allow", Action = ["cloudwatch:GetDashboard", "cloudwatch:PutDashboard", "cloudwatch:DeleteDashboards"], Resource = "arn:aws:cloudwatch::${local.account}:dashboard/${local.prefix}-dashboard" },
      { Sid = "Topic", Effect = "Allow", Action = ["sns:CreateTopic", "sns:DeleteTopic", "sns:GetTopicAttributes", "sns:SetTopicAttributes", "sns:ListTagsForResource", "sns:TagResource", "sns:UntagResource", "sns:Subscribe", "sns:Unsubscribe", "sns:GetSubscriptionAttributes", "sns:SetSubscriptionAttributes"], Resource = "arn:aws:sns:${var.aws_region}:${local.account}:${local.prefix}-alerts*" },
      { Sid = "AlertQueue", Effect = "Allow", Action = ["sqs:CreateQueue", "sqs:DeleteQueue", "sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:SetQueueAttributes", "sqs:ListQueueTags", "sqs:TagQueue", "sqs:UntagQueue"], Resource = "arn:aws:sqs:${var.aws_region}:${local.account}:${local.prefix}-alerts" },
      ], [for statement in [
        {
          Sid = "RequestAppCertificate", Effect = "Allow", Action = "acm:RequestCertificate", Resource = "*",
          Condition = {
            StringEquals = {
              "aws:RequestedRegion" = var.aws_region, "aws:RequestTag/Project" = var.project, "acm:ValidationMethod" = "DNS"
            },
            "ForAllValues:StringEquals" = { "acm:DomainNames" = [var.https_domain_name] }
          }
        },
        {
          Sid       = "ManageProjectCertificates", Effect = "Allow",
          Action    = ["acm:DescribeCertificate", "acm:ListTagsForCertificate", "acm:AddTagsToCertificate", "acm:RemoveTagsFromCertificate", "acm:DeleteCertificate"],
          Resource  = "arn:aws:acm:${var.aws_region}:${local.account}:certificate/*",
          Condition = { StringEquals = { "aws:ResourceTag/Project" = var.project, "aws:ResourceTag/Environment" = "dev" } }
        },
        {
          Sid      = "ReadAppHostedZone", Effect = "Allow", Action = ["route53:GetHostedZone", "route53:ListResourceRecordSets"],
          Resource = "arn:aws:route53:::hostedzone/${var.https_hosted_zone_id}"
        },
        {
          Sid      = "ChangeAppAliasOnly", Effect = "Allow", Action = "route53:ChangeResourceRecordSets",
          Resource = "arn:aws:route53:::hostedzone/${var.https_hosted_zone_id}",
          Condition = { "ForAllValues:StringEquals" = {
            "route53:ChangeResourceRecordSetsNormalizedRecordNames" = [var.https_domain_name],
            "route53:ChangeResourceRecordSetsRecordTypes"           = ["A"],
            "route53:ChangeResourceRecordSetsActions"               = ["CREATE", "UPSERT", "DELETE"]
          } }
        },
        {
          Sid      = "ChangeAppCertificateValidationOnly", Effect = "Allow", Action = "route53:ChangeResourceRecordSets",
          Resource = "arn:aws:route53:::hostedzone/${var.https_hosted_zone_id}",
          Condition = {
            "ForAllValues:StringLike" = { "route53:ChangeResourceRecordSetsNormalizedRecordNames" = ["_*.${var.https_domain_name}"] },
            "ForAllValues:StringEquals" = {
              "route53:ChangeResourceRecordSetsRecordTypes" = ["CNAME"],
              "route53:ChangeResourceRecordSetsActions"     = ["CREATE", "UPSERT", "DELETE"]
            }
          }
        },
        { Sid = "WaitForAppDnsChanges", Effect = "Allow", Action = "route53:GetChange", Resource = "arn:aws:route53:::change/*" }
    ] : statement if var.https_domain_name != ""])
  })
}
