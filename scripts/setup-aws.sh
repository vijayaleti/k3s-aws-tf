#!/bin/bash

# setup-aws.sh - Configure AWS CLI safely

echo "Configuring AWS CLI..."
read -sp "Enter AWS Access Key ID: " AWS_ACCESS_KEY_ID
echo
read -sp "Enter AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
echo
read -p "Enter Default Region (us-east-1): " AWS_DEFAULT_REGION
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}

aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
aws configure set default.region "$AWS_DEFAULT_REGION"
aws configure set default.output "json"

echo "AWS CLI configured successfully!"
