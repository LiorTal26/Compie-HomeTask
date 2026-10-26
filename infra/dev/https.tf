# Certificate and DNS validation

resource "aws_acm_certificate" "app" {
  count             = local.https_enabled ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate_validation" {
  count           = local.https_enabled ? 1 : 0
  zone_id         = var.hosted_zone_id
  name            = one(aws_acm_certificate.app[0].domain_validation_options).resource_record_name
  type            = one(aws_acm_certificate.app[0].domain_validation_options).resource_record_type
  records         = [one(aws_acm_certificate.app[0].domain_validation_options).resource_record_value]
  ttl             = 60
  allow_overwrite = false
}

resource "aws_acm_certificate_validation" "app" {
  count                   = local.https_enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.app[0].arn
  validation_record_fqdns = [aws_route53_record.certificate_validation[0].fqdn]
}

# Application DNS alias

resource "aws_route53_record" "app" {
  count           = local.https_enabled ? 1 : 0
  zone_id         = var.hosted_zone_id
  name            = var.domain_name
  type            = "A"
  allow_overwrite = false
  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}

# HTTPS listener and ingress

resource "aws_lb_listener" "https" {
  count             = local.https_enabled ? 1 : 0
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = aws_acm_certificate_validation.app[0].certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count             = local.https_enabled ? 1 : 0
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}
