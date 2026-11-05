# AWS CLI implementation notes

These are the **AWS CLI commands documented in the appendix of my original May 2026 project report**. I have formatted them for easier reading and replaced environment-specific IDs, the bucket name and email address with placeholders. The commands show what I did in the lab; they are **not a ready-to-run deployment guide**.

> **Security note:** In the Learner Lab, I allowed SSH from `0.0.0.0/0` to test the instances. This is not recommended for a real environment. I show that choice here because it is part of the original project, but I would restrict SSH to a trusted IP address or use Systems Manager in production.

## Phase 1 — Static website hosting

### 1. Find the VPC ID

```bash
aws ec2 describe-vpcs \
  --query "Vpcs[].VpcId" \
  --output text
```

I used the default VPC in the lab environment.

### 2. Create the bastion host security group

```bash
aws ec2 create-security-group \
  --group-name bastionhost \
  --description "SG for BastionHost" \
  --vpc-id <your-vpc-id>
```

I added an SSH rule on port 22. **The following command reflects the lab configuration, not a recommended production setting.**

```bash
aws ec2 authorize-security-group-ingress \
  --group-id <bastion-sg-id> \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

### 3. Find the Amazon Linux 2023 AMI and launch the bastion host

```bash
aws ssm get-parameters \
  --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query "Parameters[0].Value" \
  --output text
```

```bash
aws ec2 run-instances \
  --image-id <ami-id> \
  --count 1 \
  --instance-type t3.micro \
  --region us-east-1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=bastion-host}]' \
  --key-name vockey \
  --security-group-ids <bastion-sg-id> \
  --iam-instance-profile Name=LabInstanceProfile
```

I connected to the bastion host with PuTTY and SSH and configured the AWS CLI in the lab environment. I have **not included the credential configuration screenshot** from the report.

### 4. Create an S3 bucket and upload the HTML file

```bash
aws s3api create-bucket \
  --bucket <your-bucket-name> \
  --region us-east-1

aws s3 cp index.html s3://<your-bucket-name>/
```

I created `index.html` using `nano`. The complete original HTML file is no longer available, so the README shows a screenshot of part of the source code instead.

### 5. Create the web server security group

```bash
aws ec2 create-security-group \
  --group-name webserver \
  --description "SG for webserver" \
  --vpc-id <your-vpc-id>
```

```bash
aws ec2 authorize-security-group-ingress \
  --group-id <webserver-sg-id> \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

### 6. Launch the web server with a user data script

```bash
aws ec2 run-instances \
  --image-id <ami-id> \
  --count 1 \
  --instance-type t3.micro \
  --region us-east-1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=web-server}]' \
  --key-name vockey \
  --security-group-ids <webserver-sg-id> \
  --user-data file://nginxinstall.sh \
  --iam-instance-profile Name=LabInstanceProfile
```

The `nginxinstall.sh` user data script installed Nginx and AWS CLI, synchronized the HTML file from S3 to `/usr/share/nginx/html`, and started Nginx. The repository's [script](../scripts/nginxinstall.sh) is a **sanitized illustrative version**, not a verified byte-for-byte copy of the original script.

I then opened the web server's public IP address in a browser to check that the website worked.

## Phase 2 — CloudWatch and SNS monitoring

### 7. Create the SNS topic and email subscription

```bash
aws sns create-topic --name cpu-alerts

aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:<account-id>:cpu-alerts \
  --protocol email \
  --notification-endpoint <your-email>
```

I confirmed the email subscription before testing the alarm.

### 8. Find the web server instance ID

```bash
aws ec2 describe-instances \
  --query "Reservations[*].Instances[*].[InstanceId,Tags[?Key=='Name']|[0].Value]" \
  --output table
```

### 9. Create the CPU alarm

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "High-CPU-WebServer" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 60 \
  --threshold 70 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=<webserver-instance-id> \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:us-east-1:<account-id>:cpu-alerts \
  --region us-east-1
```

The alarm was set to trigger when average CPU usage was **above 70% for two consecutive one-minute periods**.

### 10. Test the alarm and check the result

For the lab test, I temporarily opened SSH on the web server too. Again, the `0.0.0.0/0` rule below was used in the lab and is **not recommended for production**.

```bash
aws ec2 authorize-security-group-ingress \
  --group-id <webserver-sg-id> \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

On the web server, I started two CPU load processes:

```bash
yes > /dev/null &
yes > /dev/null &
```

I checked the alarm state from the bastion host:

```bash
aws cloudwatch describe-alarms \
  --alarm-names "High-CPU-WebServer" \
  --query "MetricAlarms[*].StateValue" \
  --output text
```

The state changed to `ALARM`, and I received an SNS email. I then stopped the test processes:

```bash
killall yes
```

I checked the alarm again and confirmed that it returned to `OK`.

## What I would change in a real environment

- Restrict SSH access or use AWS Systems Manager Session Manager
- Use HTTPS for the public website
- Review IAM permissions using the principle of least privilege
- Consider a public load balancer and private subnet for the web server
- Use infrastructure as code for repeatable deployments

The last two items were **future improvement ideas**, not implemented features.

## Source

Commands are based on the **Appendix: CLI commands used in phase 1 and phase 2** of my original project report (*Static Web Hosting*, 14 May 2026). I removed specific account identifiers and reformatted line breaks. The original report itself is not uploaded because it contains AWS credentials.
