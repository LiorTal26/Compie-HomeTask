# Validation evidence

Captured on October 25, 2026, for AWS account `108782097005` in `il-central-1`. See [validation-summary.md](validation-summary.md) for results and remaining verification limits.

| Evidence | What it shows |
|---|---|
| [Live application](live%20app%20running%20from%20ec2%20proof.png) | Public ALB URL, rendered interface, and a stored demo item. |
| [Health screenshot](health-check-proof.png), [fresh health response](live-health.json) | The deployed app successfully queries DynamoDB and reports its release commit. |
| [Application workflow screenshot](CI-CD-PROOF.png), [workflow metadata](workflow-run.json) | Successful manually dispatched build, checks, ECR push, ASG refresh, and public verification. |
| [ASG overview](ASG%20PROOF.png) | Desired capacity one, limits one to two, and a healthy running instance. |
| [Replacement activity](ASG%20REPLACMENT%20PROOF%20FROM%20CD.png) | New instance launched before the old instance was terminated in response to Instance Refresh. |
| [Dev apply](terraform%20apply%20output%20proof.png) | Local Terraform apply completed with 40 resources added. |
| [Bootstrap plan](terraform-bootstrap-plan.txt), [dev plan](terraform-dev-plan.txt) | Final plans both exited zero and reported no changes. These are text results, not state or binary plan files. |
| [Security checks](security-checks.json) | No instance public IP, enabled DynamoDB KMS encryption, an enabled AWS-managed configuration key, and simulated CI secret-access denial. |
| [Application logs](app-logs.txt) | CloudWatch request records with status, request ID, and release version. |
| [Instance logs](instance-logs.txt) | CloudWatch-collected cloud-init and package installation output. |
| [Alarm notification](alert-alarm.json), [recovery notification](alert-recovery.json) | CloudWatch state changes received through SNS/SQS. |
| [Bootstrap record](aws-bootstrap.md), [local checks](local-validation.md), [local screenshot](local-flask.jpg) | Earlier foundation and local application validation. |

The alarm JSON files were decoded from the SQS message bodies supplied by the operator. The ALARM occurred during initial provisioning because two metric periods had no data; recovery followed a healthy target. These messages prove delivery of the initial alarm and recovery. They are not the later forced test message with reason `Assignment notification test`, and do not demonstrate a deliberate application outage.

Screenshots and command output retain resource names, account IDs, and ARNs for traceability. They contain no application configuration values, AWS credentials, GitHub tokens, Terraform state, or assignment PDF.
