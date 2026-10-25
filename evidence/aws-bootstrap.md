# AWS bootstrap — October 25, 2026

Account: `108782097005`. Region: `il-central-1`.

- Saved plan reviewed: 16 additions, zero changes, zero deletions.
- Applied: 16 foundation resources, including ECR, state storage, configuration metadata, release parameter, roles, instance profile, and policies.
- Existing GitHub OIDC provider reused and preserved.
- CI trust restricted to `LiorTal26/Compie-HomeTask`, repository ID `1433129391`, owner ID `91834069`, branch `main`.
- Demo runtime configuration populated in Secrets Manager outside Terraform state.
- IAM simulation: both application and infrastructure CI roles receive `explicitDeny` for `secretsmanager:GetSecretValue`.
- Post-apply bootstrap plan: no changes.

This records the foundation stage. The dev environment and application release were subsequently deployed and verified; see [validation-summary.md](validation-summary.md). A final bootstrap plan also reports no changes in [terraform-bootstrap-plan.txt](terraform-bootstrap-plan.txt).
