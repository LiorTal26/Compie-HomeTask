# Validation evidence

Store actual screenshots and sanitized command results here before packaging.

Required browser evidence: the application while live on its public AWS URL.

Useful additional evidence: `/health`, the successful GitHub Actions release, a healthy ALB target, private instance networking, application/startup log streams, and the received alarm notification.

Save the received SNS/SQS alarm message as sanitized JSON. A forced alarm-state test validates notification wiring; it is not an outage test.
