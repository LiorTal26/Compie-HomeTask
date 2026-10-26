# Metadata only. A local bootstrap command supplies the configuration value.

resource "aws_secretsmanager_secret" "app" {
  name                    = "/${var.project}/dev/app-config"
  description             = "Runtime configuration; CI may inspect metadata but cannot retrieve values."
  recovery_window_in_days = 0
  # Omitting kms_key_id selects the AWS-managed aws/secretsmanager key.
}

# Release image reference

resource "aws_ssm_parameter" "release" {
  name  = local.release_name
  type  = "String"
  value = "UNINITIALIZED"
  lifecycle {
    ignore_changes = [value]
  }
}
