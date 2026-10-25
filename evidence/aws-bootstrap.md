# AWS bootstrap — October 25, 2026

Account: `314525640319`. Region: `il-central-1`.

- Saved plan reviewed: 16 additions, zero changes, zero deletions.
- Applied: 16 foundation resources, including ECR, state storage, configuration metadata, release parameter, roles, instance profile, and policies.
- Existing GitHub OIDC provider reused and preserved.
- CI trust restricted to `LiorTal26/Compie-HomeTask`, repository ID `1433129391`, owner ID `91834069`, branch `main`.
- Demo runtime configuration populated in Secrets Manager outside Terraform state.
- IAM simulation: both application and infrastructure CI roles receive `explicitDeny` for `secretsmanager:GetSecretValue`.
- Post-apply bootstrap plan: no changes.

This verifies bootstrap only. EC2, ALB, VPC/NAT, database runtime access, logs, alerts, and GitHub Actions still require deployment and validation.
