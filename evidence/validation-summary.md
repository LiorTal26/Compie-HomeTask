# AWS validation — October 25, 2026

Account: `108782097005`. Region: `il-central-1`. Environment: `compie-dev`.

Application: http://compie-dev-alb-783445311.il-central-1.elb.amazonaws.com

Deployed commit: `31899f1b75d45c4ed14d2f5ef674c5d4bc9cc3c1`.

| Check | Result |
|---|---|
| Live application | Public page screenshot shows the Flask interface and a stored demo record. |
| Database health | Fresh `/health` response returned HTTP 200, `database: ok`, and the deployed commit. |
| Application delivery | [Run 40201715332](https://github.com/LiorTal26/Compie-HomeTask/actions/runs/40201715332) succeeded from manual dispatch on `main`. Build, behavior checks, real DynamoDB Local CRUD, OIDC, ECR push, refresh, and public verification all passed. |
| Instance replacement | ASG activity records successful launch of `i-03754e3b267dd4806` followed by termination of `i-02b32f36f989113b7`, both caused by Instance Refresh. Desired capacity returned to one. |
| Private compute | The running instance has private address `10.42.11.22` and no public IP. |
| Networking and ASG | [Live checks](network-compute-checks.json) record public/private subnet routes, security-group rules, an internet-facing ALB, ASG capacity `1/1/2`, launch-template reference, and a healthy `/health` target. |
| CI separation | IAM simulation returned `explicitDeny` for `secretsmanager:GetSecretValue` for both CI roles. |
| Encryption | DynamoDB reports enabled KMS encryption. The configuration key is AWS-managed and enabled; the secret uses the default `aws/secretsmanager` key because Terraform omits `kms_key_id`. |
| Logs | Saved CloudWatch request records and cloud-init/package installation output. |
| Notifications | Operator-supplied SQS bodies record the initial missing-metric ALARM and subsequent recovery to OK. |
| Infrastructure drift | Final bootstrap and dev plans both exited zero with no changes. |

## Verification limits

- Push-triggered deployment is configured; the recorded end-to-end release used manual dispatch.
- Manual rollback is implemented and documented, but was not exercised.
- Local record persistence across an application restart passed. Preservation of a specific AWS item across the EC2 refresh was not separately recorded.
- Terraform restricts DynamoDB data access by role and VPC endpoint. A separate negative test from outside that endpoint was not performed.
- The replacement evidence demonstrates a deployment refresh. It does not establish recovery from an injected instance failure or a measured zero-downtime guarantee.
- The Infrastructure workflow definition was validated locally. The recorded dev apply ran through the local Terraform CLI.
- The captured notifications do not contain the later forced-test reason. Their provenance is documented in the evidence index.

The environment remains provisioned. This evidence pass performed no Terraform apply or destroy.
