#!/bin/bash
# Enables VPC Flow Logs and streams them to CloudWatch
set -e

VPC_ID="$1"
REGION="${2:-us-east-1}"

if [ -z "$VPC_ID" ]; then
  echo "Usage: $0 <VPC_ID> [REGION]"
  exit 1
fi

echo "=== Creating CloudWatch log group ==="
aws logs create-log-group \
  --log-group-name "/vpc-flow-logs/${VPC_ID}" \
  --region "$REGION"

echo "=== Creating IAM role for Flow Logs ==="
ROLE_NAME="vpc-flow-logs-role-${VPC_ID}"
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "vpc-flow-logs.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "vpc-flow-logs-policy" \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    }]
  }'

ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

echo "=== Enabling VPC Flow Logs ==="
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids "$VPC_ID" \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-destination "arn:aws:logs:${REGION}:$(aws sts get-caller-identity --query Account --output text):log-group:/vpc-flow-logs/${VPC_ID}" \
  --deliver-logs-permission-arn "$ROLE_ARN" \
  --region "$REGION"

echo "=== Flow Logs enabled for VPC: $VPC_ID ==="
