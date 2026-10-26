# Deployment settings

variable "aws_region" {
  type        = string
  default     = "il-central-1"
  description = "Target AWS region for the dev environment."
}

variable "project" {
  type        = string
  default     = "compie"
  description = "Short lowercase project identifier."
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance size for the private application Auto Scaling Group."
}

# Optional HTTPS

variable "domain_name" {
  type        = string
  default     = ""
  description = "Custom domain/subdomain for ALB HTTPS (e.g. compie.tal-handassa.com). Leave empty for standard HTTP."
  validation {
    condition     = (var.domain_name == "") == (var.hosted_zone_id == "")
    error_message = "Set both domain_name and hosted_zone_id to enable HTTPS, or leave both empty for HTTP."
  }
}

variable "hosted_zone_id" {
  type        = string
  default     = ""
  description = "Route 53 Public Hosted Zone ID for DNS validation and alias record. Leave empty for HTTP."
}
