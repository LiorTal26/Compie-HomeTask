# AI implementation notes

AI assistance was used to reduce the initial scope, implement the Flask/Docker/Terraform/workflow files, investigate CI permissions, and organize documentation and diagrams. The user supplied the AWS account, GitHub repository, domain choice, and approval for scoped CI certificate/DNS permissions.

Claims were checked against the actual source, Terraform plans, GitHub job results, HTTP responses, AWS encryption metadata, CloudWatch logs, and screenshots. Plans were reviewed before applies. Runtime secrets were not requested for verification.

The submission records limitations explicitly: rollback, injected instance failure, CPU load-driven scaling, and a measured zero-downtime guarantee were not tested. AWS-managed KMS keys were used; a customer-managed key and second environment were deferred. New detailed snapshots stay in the local ZIP unless they were already published by the user's other work.
