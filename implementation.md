# Lean Plan for the Six-Hour Assignment

Historical planning document. The application choice was later simplified to one Python Flask application rendering HTML/CSS and accessing DynamoDB. The implemented application has no Node.js, browser JavaScript, API-only frontend, or Docker Compose. Use [README.md](README.md) for the final design and operating instructions, and [the validation summary](evidence/validation-summary.md) for completed checks.

## 1. Assessment and scope

**Yes—the earlier plan was heavier than necessary for this assessment.** The extra complexity came mainly from automatic recovery, extensive verification, and bootstrap/state-management procedures. The required AWS services themselves account for much of the work.

The assignment estimates **4–6 hours** and explicitly favors a simple, secure, working solution. Target six hours for the core submission and reserve the remaining time before tomorrow at 10:00 for troubleshooting.

**CloudWatch Logs and monitoring/alerting are mandatory. A CloudWatch dashboard is a bonus.** This distinction appears in :codex-file-citation{path="C:\Users\liorta\Compie-HomeTask\compie-devops-assigment_v2.pdf" purpose="source"}.

Keep the agreed choices: vanilla JavaScript frontend, small Node.js backend, DynamoDB, Terraform, GitHub Actions, `il-central-1`, and a temporary US$15 spending target.

## 2. Minimum complete implementation

### Application and container

Build the small Items Board with add, list, and delete operations. Keep styling basic.

- `/` serves the interface.
- `/health` performs a real DynamoDB query and returns `200` or `503`.
- `/api/items` supports listing and adding records; `/api/items/:id` supports deletion.
- `/api/config` provides the public welcome message and release version.
- Validate short text input and render it safely.
- Use Docker Compose with DynamoDB Local to demonstrate a clean local run.
- Use a supported Node image, locked dependencies, a non-root user, and port `8080`.

Keep a few meaningful smoke checks covering health and CRUD. Defer a comprehensive test suite.

### AWS infrastructure

Retain the components required to satisfy the assignment:

- One VPC, two public subnets, and two private subnets across two AZs.
- Public ALB; private EC2 ASG with **min 1 / desired 1 / max 2**.
- One NAT gateway for outbound service access.
- Amazon Linux 2023, `t3.micro`, no instance public IPs, and administration through SSM.
- Instance inbound traffic on `8080` only from the ALB security group.
- ECR for application images.
- DynamoDB on-demand capacity, accessed through a gateway endpoint.
- Endpoint, table, and IAM policies restricting database data access to the application role through that endpoint.

One running instance and one NAT gateway are acceptable cost choices for this exercise. Explain their availability limitations in the README.

### Configuration and IAM

Keep application configuration in Secrets Manager, using its AWS-managed KMS key. Terraform creates the secret metadata; one documented bootstrap command populates its value.

Use separate identities for:

- EC2 runtime access.
- Application build and deployment.
- Infrastructure plan/apply.

CI identities cannot retrieve application secret values. Use GitHub OIDC rather than stored AWS access keys.

### Terraform and GitHub Actions

**One repository with separate workflows is appropriate and maintainable.**

Use two small Terraform roots:

- Bootstrap: state bucket, ECR, foundational identities, configuration metadata, and release parameter. Keep its state locally and exclude it from submission.
- Dev: network, database, compute, load balancer, and operational resources. Store its state in S3 with encryption, versioning, and locking.

This removes the earlier bootstrap-state migration procedure.

The infrastructure workflow validates and plans changes, with manually triggered apply. The application workflow builds, checks, pushes, and deploys application changes from `main`.

For deployment:

1. Push a commit-tagged image and resolve its digest.
2. Update a non-secret SSM release parameter.
3. Start ASG Instance Refresh with `SkipMatching=false`.
4. Launch the replacement before terminating the previous instance.
5. Wait for healthy targets and verify `/health` and the release version.

The instance startup service reads that digest and runs the container. Terraform owns infrastructure; the application workflow owns the release parameter’s value.

**Simplify recovery:** document and support manually redeploying a previous image digest. Defer automatic rollback orchestration. Serialize infrastructure applies and application deployments.

## 3. Required logging, encryption, and monitoring

| Requirement | Minimum implementation | Evidence |
|---|---|---|
| Application logs | Docker stdout/stderr → CloudWatch Logs; include request status and release version. | Find an actual application request in the log stream. |
| Instance logs | CloudWatch agent collects bootstrap/startup logs. | Show successful startup or a useful failure message. |
| Log retention | Seven days; avoid logging configuration contents. | Terraform configuration and existing log groups. |
| Database encryption | Explicit DynamoDB KMS encryption using `aws/dynamodb`. | Table encryption settings. |
| Configuration encryption | Secrets Manager using `aws/secretsmanager`. | Secret metadata and Terraform configuration. |
| Monitoring | One CloudWatch alarm when the target group has fewer than one healthy target for two consecutive one-minute periods. | Alarm configuration. |
| Alert destination | CloudWatch alarm → SNS → subscribed SQS queue, with the required queue policy. | Receive a test alarm notification in SQS. |
| CloudWatch dashboard | Deferred bonus. | Add only after the core submission is complete. |

One correctly configured, tested alarm satisfies the stated monitoring requirement. Extra alarms, custom metrics, and dashboards can wait.

## 4. Six-hour sequence and completion criteria

| Working time | Focus |
|---|---|
| 0:00–0:45 | Build the minimal application and verify its Docker run locally. |
| 0:45–2:45 | Bootstrap and provision the AWS stack, including operational resources. |
| 2:45–3:45 | Complete both GitHub Actions workflows and demonstrate a release. |
| 3:45–4:30 | Verify CloudWatch logs, encryption, alarm configuration, and notification delivery. |
| 4:30–5:15 | Check CRUD, persistence across replacement, private networking, and manual rollback. |
| 5:15–6:00 | Finish README, capture screenshots, package the submission, and tear down. |

The submission is complete when:

- The live application performs database operations.
- `/health` verifies database connectivity.
- A GitHub change reaches the running application.
- Private compute, restricted database access, and separated IAM are demonstrated.
- Logs are usable, KMS encryption is configured, and an alert reaches its destination.
- The README explains bootstrap, apply/destroy, workflow triggers, capacity, and rollback.
- The archive contains the implementation and evidence, with credentials and state excluded.

Keep the repository private and use disposable public demo data. Defer HTTPS, dashboards, customer-managed keys, dynamic scaling, additional environments, and other bonuses until these completion criteria pass.
