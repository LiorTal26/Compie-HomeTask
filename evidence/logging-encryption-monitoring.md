# Logging, encryption, and monitoring verification

Read-only live AWS checks were performed on 2026-10-25 in `il-central-1` using the scoped `compie-operator` role. No secret values were retrieved and no AWS resources were changed. Raw metadata and log samples are in [logging-encryption-monitoring.json](logging-encryption-monitoring.json).

| Assignment requirement | Verified result |
|---|---|
| Application logs | `/compie/dev/app` contains request timestamps, request IDs, method/path, status, duration, and the deployed release SHA. Recent `/health` entries return HTTP 200 for release `8d4597bfa0d4dee94a4208f35eb77a92cb073c48`. |
| Instance logs | `/compie/dev/instance` contains the current instance's service, bootstrap, and cloud-init streams. Startup records confirm the application service was installed and cloud-init completed. |
| Retention | Both log groups retain logs for seven days. |
| Database encryption | `compie-dev-items` reports encryption `ENABLED`, `SSEType: KMS`, and the `aws/dynamodb` key ARN. |
| Configuration encryption | `/compie/dev/app-config` has an `AWSCURRENT` version and uses the default AWS-managed `aws/secretsmanager` KMS key. |
| Monitoring | `compie-dev-no-healthy-targets` monitors the ALB target group's minimum `HealthyHostCount < 1` for two consecutive 60-second periods. Missing data is breaching. Actions are enabled; current state is `OK`. |
| Alert endpoint | CloudWatch publishes to SNS `compie-dev-alerts`, which has one confirmed SQS subscription to queue `compie-dev-alerts`. Topic policy restricts publishing to the account's specific CloudWatch alarm; queue policy restricts SNS delivery to that topic. |
| Delivery evidence | [Initial alarm](alert-alarm.json) and [recovery](alert-recovery.json) were previously received from SQS. Current alarm history also records successful SNS actions, including the earlier forced test with reason `Assignment notification test`. No new outage or forced state was introduced during this check. |
| Production receiver | The main README documents an operations email or incident-management integration as the real receiver. The SQS queue is the assignment's placeholder endpoint. |

The existing SNS and queue policy statements were checked directly against live AWS metadata. This verification does not add dashboards or other bonus infrastructure.

## KMS keys

| Alias | Key ID | Manager | State |
|---|---|---|---|
| `aws/dynamodb` | `b64bd3b3-18d3-4cca-b452-c1f838fdcd83` | AWS | Enabled |
| `aws/secretsmanager` | `9f03842c-68db-4370-b658-dcf6756df22a` | AWS | Enabled |

In [the database Terraform](../infra/dev/data.tf), `server_side_encryption { enabled = true }` selects the AWS-managed DynamoDB key. The table's live key ARN matches the key resolved by `alias/aws/dynamodb`.

[The Secrets Manager resource](../infra/bootstrap/parameters.tf) intentionally omits `kms_key_id`. AWS uses `aws/secretsmanager` by default. `DescribeSecret` omits the key identifier for this default, so its `KmsKeyId: null` response does not mean the secret is unencrypted. See [AWS Secrets Manager encryption documentation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/security-encryption.html) and [DynamoDB encryption documentation](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/EncryptionAtRest.html).

These are real AWS KMS keys managed by AWS; a separate Terraform `aws_kms_key` resource and direct application encryption calls are unnecessary for this requirement. The services perform encryption and decryption transparently. CloudWatch log groups have no additional KMS key association; SQS uses SQS-managed encryption. The mandatory database and configuration-store KMS coverage is verified above.

This report and its detailed AWS snapshot are supplied locally in the submission ZIP only.
