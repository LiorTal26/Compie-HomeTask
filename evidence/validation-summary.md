# Validation summary — October 26, 2026

Latest verification: the readability cleanup at `6880be6` passed [Application delivery](https://github.com/LiorTal26/Compie-HomeTask/actions/runs/40281599765) and an [Infrastructure no-change plan](https://github.com/LiorTal26/Compie-HomeTask/actions/runs/40281599723). HTTPS database health, six previously recorded items, private addressing, and encrypted replacement EBS were verified. Earlier captures below retain their original versions.

Latest deployed application commit: `47ad780638d8667aa61cbfbc466843cd50155c6c`. Earlier records below retain their original release versions.

| Check | Result |
|---|---|
| Application CI/CD | [Run 40211715134](https://github.com/LiorTal26/Compie-HomeTask/actions/runs/40211715134) succeeded automatically from a push to `main`: build, unit checks, real DynamoDB Local CRUD, OIDC, ECR push, ASG refresh, and live verification. |
| Infrastructure CI | Initial core plan/apply runs passed. A later plan-only run proposed removing HTTPS because repository DNS inputs were absent; those inputs were corrected and an existing-HTTPS guard added. The final verification run is recorded below. |
| Live application | `/` and `/health` returned HTTP 200; the health response matched the pushed commit and reported `database: ok`. |
| Release and persistence | The replacement completed successfully, its target was healthy, and existing demo records remained after replacement. |
| Private compute | The replacement EC2 instance has no public IP. |
| IAM repair | Added only `secretsmanager:GetResourcePolicy` on the app configuration secret. Secret-value API denial remains unchanged. |
| Logs and drift | New-version request logs were present in CloudWatch. Post-repair bootstrap and dev plans reported no changes. |
| Credentials | Source and evidence were scanned for credential patterns. Credential files, state, binary plans, local config, and the assignment PDF are excluded from the submission package. |
| Dynamic ASG scaling (CPU 70%) | Verified deployed target-tracking configuration, 60-second warmup, and AWS-managed high/low alarms for `compie-dev-asg`. No CPU stress test or actual load-based capacity change was exercised. |
| CloudWatch dashboard | Verified `compie-dev-dashboard` and its four widgets against live AWS metrics. Terraform output: `dashboard_name = "compie-dev-dashboard"`. Screenshot is in the local submission ZIP only. |
| Architecture visual diagram | Generated and visually checked a PNG architecture image and editable SVG from the Terraform layout; embedded at the start of the README. Earlier HTML diagrams remain in the ZIP. |
| Bonus apply | Reviewed saved Terraform plan applied: 2 additions, 0 changes, 0 destroys. The running instance remained healthy and was not replaced. |
| Bonus CI plan/apply | Commit `f535ec4` passed [push plan 40217331032](https://github.com/LiorTal26/Compie-HomeTask/actions/runs/40217331032) and [manual apply 40217381960](https://github.com/LiorTal26/Compie-HomeTask/actions/runs/40217381960). CI applied zero changes and verified database health. Scoped scaling-policy/dashboard permissions were added with user approval; secret-value denial remains unchanged. |

## Evidence scope

The public repository contains earlier sanitized snapshots and links to the latest public workflow runs. New detailed AWS resource snapshots, logs, and database item-ID comparisons are kept only in the local submission ZIP. The ZIP overlays those private evidence files onto the public source checkout and includes public main-branch Git history.

## Verification limits

- Manual rollback is implemented and documented but was not exercised.
- Infrastructure manual-apply mode passed for the deployed bonus configuration with no resource changes. Initial resource creation used the local Terraform CLI; CI creation/deletion of these bonus resources has not been exercised.
- A rolling replacement was demonstrated; an injected instance failure and measured zero-downtime guarantee were not tested.
- Root credentials remain in the explicitly named bootstrap profile. Routine CLI inspection uses the read-only operator role.
- The earlier root database comparison succeeded outside the VPC; the resource-policy denial test passed for the non-root operator.
- Captured alarm messages demonstrate initial ALARM/recovery delivery rather than the later forced-test reason.

The environment remains provisioned. The earlier CI repair added an IAM metadata-read action. The later bonus apply added a scaling policy and dashboard; the approved CI permission update changed one inline policy. Both subsequent CI plan and manual apply passed. Earlier application captures reference `8d4597b`; the current release is listed above. The later EBS update performed a rolling replacement; the current root volume is encrypted. No Terraform destroy was performed.

## HTTPS, encrypted EBS, and PR checks

- Live HTTPS `/` and `/health` returned HTTP 200, with database health `ok`; TLS 1.3 and the hostname were verified, and HTTP returned a 301 redirect to HTTPS.
- ACM is `ISSUED`. The current healthy instance uses launch-template version 2 and an encrypted root EBS volume.
- [PR #1](https://github.com/LiorTal26/Compie-HomeTask/pull/1) merged after [read-only Terraform/container checks](https://github.com/LiorTal26/Compie-HomeTask/actions/runs/40227492186) passed. Branch protection is not claimed.
- The later all-zone DNS permission was replaced with the app-only certificate/DNS scope approved by the user. IAM simulations allow the app alias/validation records, deny an unrelated hostname, and explicitly deny application secret-value retrieval.
- The green [plan-only run 40273788472](https://github.com/LiorTal26/Compie-HomeTask/actions/runs/40273788472) proposed six HTTPS deletions because its DNS variables were missing. It did not apply. Repository variables were corrected and the workflow now rejects empty DNS inputs when HTTPS already exists.

New detailed metadata and IAM simulation output from this review are included in the local ZIP only. Existing public demo evidence is retained.


Final closeout: [Infrastructure run 40277529968](https://github.com/LiorTal26/Compie-HomeTask/actions/runs/40277529968) succeeded and reported **No changes**. [Application run 40277762630](https://github.com/LiorTal26/Compie-HomeTask/actions/runs/40277762630) then built, tested, pushed and deployed `47ad780` through HTTPS. Independent live checks verified the commit, database health, encrypted AWS-managed-KMS root EBS, private addressing, successful refresh, and preservation of existing demo item IDs. Detailed current metadata and fresh screenshots are in the ZIP only.
