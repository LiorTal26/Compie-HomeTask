# Local validation — October 25, 2026

These results apply to the local Docker environment. At the time of these checks, no AWS infrastructure had been provisioned and no GitHub Actions run had been performed. Subsequent bootstrap results are recorded in `aws-bootstrap.md`.

| Check | Result |
|---|---|
| Flask image build | Passed with Python 3.13, Flask 3.1.3, boto3 1.43.118, and Gunicorn 26.2.0. |
| Container user | `appuser`, not root. |
| Python dependency consistency | `pip check`: no broken requirements. |
| Behavior checks | Three unittest cases passed: forms/HTML escaping/deletion; invalid and oversized input; DB failure and health status. |
| Real database connection | `/health` returned `200` with `database: ok` against DynamoDB Local. |
| HTTP form submission | Added a record through the running Gunicorn server and read it on the rendered page. |
| Persistence | Restarted only the Flask container; the record remained in the database. |
| Browser add/delete | Submitted an HTML form, saw the new item, and deleted the earlier persistence-test item through its form. |
| Browser JavaScript | No JavaScript files or script elements. |
| Terraform | Both roots passed `terraform validate`; recursive formatting check passed. |
| GitHub Actions definitions | Both passed actionlint 1.7.7. Execution/OIDC/rollout remain unverified. |

Local preview: http://localhost:8080

![Local Flask application](local-flask.jpg)

## Deferred AWS verification

Live ALB URL, private EC2 placement, ECR release, GitHub OIDC authentication, instance refresh/rollback, DynamoDB endpoint enforcement, CloudWatch logs, KMS configuration, alert delivery, and teardown require an actual AWS deployment.
