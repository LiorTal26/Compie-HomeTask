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
| [Networking and compute checks](network-compute-checks.json) | Live VPC/subnet routing, security groups, private EC2, public ALB, launch-template reference, ASG capacity, and healthy target. |
| [Image, config, and IAM checks](image-config-iam-checks.json) | ECR release digest, secret metadata, instance profile, OIDC trust, attached policies, permission simulations, and the root operator follow-up. No secret values are included. |
| [Database configuration](database-checks.json) | Active on-demand DynamoDB table, deployed resource/endpoint policies, encryption, and successful live database health. |
| [Non-root database denial](database-operator-probe.json) | Explicit table resource-policy denial from outside the VPC, including with temporarily allowed COUNT permission; temporary permission removed. |
| [Root comparison](database-outside-endpoint.json), [initial temporary-role audit](database-nonroot-probe.json) | Earlier root queries succeeded outside the VPC. An initial role session could not be obtained; the temporary role was deleted. These results are retained separately from the successful non-root denial test. |
| [Operator setup](operator-setup.json) | Default CLI switched to a scoped read-only assumed role. Source user can only assume that role; credential values are not included. |
| [Application logs](app-logs.txt), [recent delivery check](app-runtime-log-proof.json) | CloudWatch request records with status, request ID, and release version, including a fresh runtime logging check. |
| [Instance logs](instance-logs.txt) | CloudWatch-collected cloud-init and package installation output. |
| [Alarm notification](alert-alarm.json), [recovery notification](alert-recovery.json) | CloudWatch state changes received through SNS/SQS. |
| [Bootstrap record](aws-bootstrap.md), [local checks](local-validation.md), [local screenshot](local-flask.jpg) | Earlier foundation and local application validation. |
| [Local Docker HTTP checks](docker-local-http.json), [runtime inspection](docker-runtime.json) | Rechecked `/` and `/health` on the host port; healthy non-root container, read-only root filesystem, dropped capabilities, and Gunicorn. |

The alarm JSON files were decoded from the SQS message bodies supplied by the operator. The ALARM occurred during initial provisioning because two metric periods had no data; recovery followed a healthy target. These messages prove delivery of the initial alarm and recovery. They are not the later forced test message with reason `Assignment notification test`, and do not demonstrate a deliberate application outage.

Screenshots and command output retain resource names, account IDs, and ARNs for traceability. They contain no application configuration values, AWS credentials, GitHub tokens, Terraform state, or assignment PDF.
