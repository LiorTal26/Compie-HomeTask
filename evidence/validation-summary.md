# Validation summary — October 25, 2026

Latest deployed application commit: `8d4597bfa0d4dee94a4208f35eb77a92cb073c48`.

| Check | Result |
|---|---|
| Application CI/CD | [Run 40211715134](https://github.com/LiorTal26/Compie-HomeTask/actions/runs/40211715134) succeeded automatically from a push to `main`: build, unit checks, real DynamoDB Local CRUD, OIDC, ECR push, ASG refresh, and live verification. |
| Infrastructure CI | [Run 40211715491](https://github.com/LiorTal26/Compie-HomeTask/actions/runs/40211715491) passed formatting, validation, OIDC, backend initialization, and a no-change dev plan. Apply was skipped for this push event. |
| Live application | `/` and `/health` returned HTTP 200; the health response matched the pushed commit and reported `database: ok`. |
| Release and persistence | The replacement completed successfully, its target was healthy, and existing demo records remained after replacement. |
| Private compute | The replacement EC2 instance has no public IP. |
| IAM repair | Added only `secretsmanager:GetResourcePolicy` on the app configuration secret. Secret-value API denial remains unchanged. |
| Logs and drift | New-version request logs were present in CloudWatch. Post-repair bootstrap and dev plans reported no changes. |
| Credentials | Source and evidence were scanned for credential patterns. Credential files, state, binary plans, local config, and the assignment PDF are excluded from the submission package. |
| Dynamic ASG scaling (CPU 70%) | Verified deployed target-tracking configuration, 60-second warmup, and AWS-managed high/low alarms for `compie-dev-asg`. No CPU stress test or actual load-based capacity change was exercised. |
| CloudWatch dashboard | Verified `compie-dev-dashboard` and its four widgets against live AWS metrics. Terraform output: `dashboard_name = "compie-dev-dashboard"`. Screenshot is in the local submission ZIP only. |
| Architecture visual diagram | Generated standalone HTML diagrams, supplied in the ZIP. Browser capture of the local file was blocked, so no architecture screenshot is claimed. |
| Bonus apply | Reviewed saved Terraform plan applied: 2 additions, 0 changes, 0 destroys. The running instance remained healthy and was not replaced. |

## Evidence scope

The public repository contains earlier sanitized snapshots and links to the latest public workflow runs. New detailed AWS resource snapshots, logs, and database item-ID comparisons are kept only in the local submission ZIP. The ZIP overlays those private evidence files onto the public source checkout and includes public main-branch Git history.

## Verification limits

- Manual rollback is implemented and documented but was not exercised.
- Infrastructure manual-apply mode was not exercised; the initial dev apply used the local Terraform CLI.
- A rolling replacement was demonstrated; an injected instance failure and measured zero-downtime guarantee were not tested.
- Root credentials remain in the explicitly named bootstrap profile. Routine CLI inspection uses the read-only operator role.
- The earlier root database comparison succeeded outside the VPC; the resource-policy denial test passed for the non-root operator.
- Captured alarm messages demonstrate initial ALARM/recovery delivery rather than the later forced-test reason.

The environment remains provisioned. The CI repair applied one IAM metadata-read change without creating or deleting resources. The push-triggered Application workflow performed the instance refresh. No Terraform destroy was performed.
