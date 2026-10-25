resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project}/dev/app"
  retention_in_days = 7
}
resource "aws_cloudwatch_log_group" "instance" {
  name              = "/${var.project}/dev/instance"
  retention_in_days = 7
}
resource "aws_sns_topic" "alerts" { name = "${local.prefix}-alerts" }
resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Sid    = "CloudWatchAlarms", Effect = "Allow", Principal = { Service = "cloudwatch.amazonaws.com" },
      Action = "sns:Publish", Resource = aws_sns_topic.alerts.arn,
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account },
        ArnEquals    = { "aws:SourceArn" = "arn:aws:cloudwatch:${var.aws_region}:${local.account}:alarm:${local.prefix}-no-healthy-targets" }
      }
    }]
  })
}
resource "aws_sqs_queue" "alerts" {
  name                      = "${local.prefix}-alerts"
  message_retention_seconds = 86400
  sqs_managed_sse_enabled   = true
}
resource "aws_sqs_queue_policy" "alerts" {
  queue_url = aws_sqs_queue.alerts.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Effect    = "Allow", Principal = { Service = "sns.amazonaws.com" }, Action = "sqs:SendMessage",
      Resource  = aws_sqs_queue.alerts.arn,
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.alerts.arn } }
    }]
  })
}
resource "aws_sns_topic_subscription" "alerts" {
  topic_arn            = aws_sns_topic.alerts.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.alerts.arn
  raw_message_delivery = true
  depends_on           = [aws_sqs_queue_policy.alerts]
}
resource "aws_cloudwatch_metric_alarm" "no_healthy_targets" {
  alarm_name          = "${local.prefix}-no-healthy-targets"
  alarm_description   = "No healthy application targets for two consecutive minutes."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
  depends_on    = [aws_sns_topic_policy.alerts, aws_sns_topic_subscription.alerts]
}

resource "aws_cloudwatch_dashboard" "app" {
  dashboard_name = "${local.prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title = "ALB Target Health & Request Count"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.app.arn_suffix, "LoadBalancer", aws_lb.app.arn_suffix, { color = "#2ca02c" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { color = "#d62728" }],
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Sum", yAxis = "right", color = "#1f77b4" }]
          ]
          period = 60
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title = "ASG CPU Utilization"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.app.name, { stat = "Average", color = "#ff7f0e" }]
          ]
          # EC2 basic monitoring publishes CPU metrics every five minutes.
          period = 300
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title = "DynamoDB Consumed Capacity & Latency"
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", aws_dynamodb_table.items.name, { stat = "Sum" }],
            [".", "ConsumedWriteCapacityUnits", ".", ".", { stat = "Sum" }],
            [".", "SuccessfulRequestLatency", ".", ".", "Operation", "Query", { stat = "Average", yAxis = "right" }]
          ]
          period = 60
          region = var.aws_region
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title = "Alarm Metric & Threshold"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.app.arn_suffix, "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Minimum" }]
          ]
          annotations = {
            horizontal = [
              { value = 1, label = "Alarm Threshold (< 1)", color = "#d62728" }
            ]
          }
          period = 60
          region = var.aws_region
        }
      }
    ]
  })
}
