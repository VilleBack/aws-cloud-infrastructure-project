# Implementation notes

These notes summarize the author's May 2026 lab report. Commands use placeholders and are not a complete one-click deployment script.

## Hosting phase

- Found the default VPC ID using `aws ec2 describe-vpcs`.
- Created a bastion security group and permitted inbound SSH (TCP/22) in the learner lab.
- Retrieved the Amazon Linux 2023 AMI ID using the AWS Systems Manager public parameter.
- Launched a `t3.micro` bastion instance with the learner-lab `LabInstanceProfile` and SSH key pair.
- Created an S3 bucket in `us-east-1` and uploaded `index.html`.
- Created a separate web-server security group permitting inbound HTTP (TCP/80).
- Launched the web server with an EC2 user-data script, which installed Nginx and AWS CLI, synchronized the S3 content into the Nginx document root, and started/enabled the service.
- Confirmed that the static page rendered through the web server's public IPv4 address.

## Monitoring phase

- Created SNS topic `cpu-alerts` and confirmed an email subscription.
- Created CloudWatch alarm `High-CPU-WebServer` with:
  - Metric: `AWS/EC2` / `CPUUtilization`
  - Statistic: `Average`
  - Period: 60 seconds
  - Threshold: strictly greater than 70%
  - Evaluation periods: 2
  - Alarm action: SNS topic
- Temporarily generated CPU load using two background `yes > /dev/null &` processes.
- Verified alarm transitioned to `ALARM` and SNS delivered an email notification.
- Stopped the load with `killall yes` and verified the alarm returned to `OK`.

## Important distinctions

- Nginx on EC2 served the website; S3 was the content source.
- CPU load was deliberately generated for testing; it was not real user traffic.
- The report proposed private subnets, a load balancer and scaling as **future improvements**, not implemented features.
- The lab used public SSH ingress for testing. This should not be copied into a production environment.

## Evidence to add later

Only sanitized screenshots should be included, such as:

1. Architecture diagram without account identifiers
2. Website successfully rendered in the browser
3. CloudWatch alarm configuration and state (without account or resource IDs)
4. Redacted SNS email alert

Do not upload the original report without properly redacting the AWS access key, secret key, session token and account-specific identifiers.
