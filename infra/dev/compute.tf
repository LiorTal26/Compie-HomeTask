resource "aws_lb" "app" {
  name               = "${local.prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}
resource "aws_lb_target_group" "app" {
  name                 = "${local.prefix}-app"
  port                 = 8080
  protocol             = "HTTP"
  target_type          = "instance"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 20
  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
resource "aws_launch_template" "app" {
  name_prefix            = "${local.prefix}-"
  image_id               = data.aws_ssm_parameter.ami.value
  instance_type          = var.instance_type
  update_default_version = true
  iam_instance_profile { name = "${local.prefix}-instance" }
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app.id]
    delete_on_termination       = true
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 12
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }
  tag_specifications {
    resource_type = "instance"
    tags          = { Name = local.prefix, Project = var.project, Environment = "dev" }
  }
  tag_specifications {
    resource_type = "volume"
    tags          = { Name = local.prefix, Project = var.project, Environment = "dev" }
  }
  user_data = base64encode(templatefile("${path.module}/user-data.sh.tftpl", {
    region            = var.aws_region
    ecr_registry      = local.ecr_registry
    ecr_repository    = local.ecr_repo
    release_parameter = local.release_name
    config_secret_arn = data.aws_secretsmanager_secret.app.arn
    app_log_group     = aws_cloudwatch_log_group.app.name
    host_log_group    = aws_cloudwatch_log_group.instance.name
  }))
}
resource "aws_autoscaling_group" "app" {
  name                      = "${local.prefix}-asg"
  min_size                  = 1
  desired_capacity          = 1
  max_size                  = 2
  vpc_zone_identifier       = aws_subnet.private[*].id
  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 60
  wait_for_capacity_timeout = "15m"
  min_elb_capacity          = 1
  launch_template {
    id      = aws_launch_template.app.id
    version = tostring(aws_launch_template.app.latest_version)
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
      instance_warmup        = 60
      skip_matching          = false
    }
  }
  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = "dev"
    propagate_at_launch = true
  }
  depends_on = [
    aws_lb_listener.http, aws_route.nat, aws_route_table_association.private,
    aws_dynamodb_resource_policy.items, aws_vpc_security_group_egress_rule.https,
    aws_vpc_security_group_ingress_rule.app, aws_vpc_security_group_egress_rule.alb_to_app
  ]
}
