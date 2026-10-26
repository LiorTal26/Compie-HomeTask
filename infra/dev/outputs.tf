# Application and compute

output "application_url" {
  description = "Public URL to access the application (HTTPS if custom domain configured, else ALB HTTP DNS)."
  value       = local.https_enabled ? "https://${var.domain_name}" : "http://${aws_lb.app.dns_name}"
}

output "asg_name" {
  description = "Name of the application Auto Scaling Group."
  value       = aws_autoscaling_group.app.name
}

output "target_group_arn" {
  description = "ARN of the ALB target group forwarding traffic to private instances."
  value       = aws_lb_target_group.app.arn
}

# Database

output "database_table" {
  description = "Name of the KMS-encrypted DynamoDB table."
  value       = aws_dynamodb_table.items.name
}

output "dynamodb_endpoint_id" {
  description = "ID of the DynamoDB Gateway VPC Endpoint."
  value       = aws_vpc_endpoint.dynamodb.id
}

# Monitoring and alerting

output "alarm_name" {
  description = "CloudWatch metric alarm monitoring unhealthy ALB targets."
  value       = aws_cloudwatch_metric_alarm.no_healthy_targets.alarm_name
}

output "alert_queue_url" {
  description = "URL of the SQS alert receiver queue."
  value       = aws_sqs_queue.alerts.url
}

output "application_log_group" {
  description = "CloudWatch log group for application container logs."
  value       = aws_cloudwatch_log_group.app.name
}

output "instance_log_group" {
  description = "CloudWatch log group for EC2 instance bootstrap and system logs."
  value       = aws_cloudwatch_log_group.instance.name
}

output "dashboard_name" {
  description = "Name of the CloudWatch observability dashboard."
  value       = aws_cloudwatch_dashboard.app.dashboard_name
}
