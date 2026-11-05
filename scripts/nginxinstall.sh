#!/bin/bash
# Sanitized illustrative EC2 user-data example based on the documented lab.
# Replace the bucket placeholder; do not run unchanged.
set -euo pipefail

yum update -y
yum install -y nginx aws-cli
aws s3 sync s3://YOUR_BUCKET_NAME/ /usr/share/nginx/html/
systemctl start nginx
systemctl enable nginx
