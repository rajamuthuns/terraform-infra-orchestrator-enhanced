#!/bin/bash

# Automated Backend Setup for Multi-Account Deployment
# This script creates S3 buckets and DynamoDB tables for a specific account/environment
# Usage: ./setup-backend-per-account.sh [ACCOUNT_ID]
# If no ACCOUNT_ID provided, processes all environments

set -e

# Read account configuration
ACCOUNTS_FILE="config/aws-accounts.json"

if [ ! -f "$ACCOUNTS_FILE" ]; then
  echo "Error: $ACCOUNTS_FILE not found"
  exit 1
fi

# Get target account ID from command line argument
TARGET_ACCOUNT_ID="$1"

# Function to find environment for a given account ID
find_environment_for_account() {
  local target_account="$1"
  for env in $(jq -r 'keys[]' "$ACCOUNTS_FILE"); do
    local account_id=$(jq -r ".${env}.account_id" "$ACCOUNTS_FILE")
    if [ "$account_id" = "$target_account" ]; then
      echo "$env"
      return 0
    fi
  done
  return 1
}

# Store original credentials to restore between environments
ORIGINAL_AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
ORIGINAL_AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
ORIGINAL_AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN"

# Function to setup backend for an environment
setup_backend() {
  local env=$1
  local account_id=$2
  local role_name=$3
  
  echo "Setting up backend for environment: $env (Account: $account_id)"
  
  # Restore original org master account credentials before assuming role
  export AWS_ACCESS_KEY_ID="$ORIGINAL_AWS_ACCESS_KEY_ID"
  export AWS_SECRET_ACCESS_KEY="$ORIGINAL_AWS_SECRET_ACCESS_KEY"
  export AWS_SESSION_TOKEN="$ORIGINAL_AWS_SESSION_TOKEN"
  
  # Assume OrganizationAccountAccessRole for the target account
  ROLE_ARN="arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole"
  
  echo "Assuming role: $ROLE_ARN"
  CREDENTIALS=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name "backend-setup-${env}" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text)
  
  export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | cut -d' ' -f1)
  export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | cut -d' ' -f2)
  export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | cut -d' ' -f3)
  
  # Backend resource names
  BUCKET_NAME="terraform-state-${env}-${account_id}"
  DYNAMODB_TABLE="terraform-state-locks-${env}"
  
  # Create S3 bucket (with error handling for existing bucket)
  echo "Creating S3 bucket: $BUCKET_NAME"
  if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Bucket $BUCKET_NAME already exists, skipping creation"
  else
    # For us-east-1, don't specify LocationConstraint
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region us-east-1
    
    # Enable versioning
    aws s3api put-bucket-versioning \
      --bucket "$BUCKET_NAME" \
      --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption \
      --bucket "$BUCKET_NAME" \
      --server-side-encryption-configuration '{
        "Rules": [{
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
          }
        }]
      }'
    
    # Block public access
    aws s3api put-public-access-block \
      --bucket "$BUCKET_NAME" \
      --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
  fi
  
  # Create DynamoDB table (with error handling for existing table)
  echo "Creating DynamoDB table: $DYNAMODB_TABLE"
  if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" 2>/dev/null; then
    echo "Table $DYNAMODB_TABLE already exists, skipping creation"
  else
    aws dynamodb create-table \
      --table-name "$DYNAMODB_TABLE" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --sse-specification Enabled=true
  fi
  
  # Update backend configuration file
  cat > "shared/backend-${env}.hcl" << EOF
bucket         = "${BUCKET_NAME}"
key            = "environments/${env}/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "${DYNAMODB_TABLE}"
encrypt        = true

workspace_key_prefix = "env"
skip_credentials_validation = false
skip_metadata_api_check = false
skip_region_validation = false
use_path_style = false

max_retries = 5
EOF
  
  # Create Terraform workspace for this environment (using root directory)
  echo "Setting up Terraform workspace for $env"
  
  # Initialize Terraform with the backend (from root directory)
  terraform init -backend-config="shared/backend-${env}.hcl"
  
  # Create workspace if it doesn't exist
  if terraform workspace list | grep -q "^\s*${env}\s*$"; then
    echo "Workspace '$env' already exists"
    terraform workspace select "$env"
  else
    echo "Creating workspace '$env'"
    terraform workspace new "$env"
  fi
  
  echo "Terraform workspace '$env' is ready"
  
  echo "Backend setup completed for $env"
  echo "Bucket: $BUCKET_NAME"
  echo "DynamoDB: $DYNAMODB_TABLE"
  echo "Workspace: $env"
  echo ""
}

# Process environments based on input
if [ -n "$TARGET_ACCOUNT_ID" ]; then
  # Process only the environment for the specified account
  echo "Looking for environment with account ID: $TARGET_ACCOUNT_ID"
  
  TARGET_ENV=$(find_environment_for_account "$TARGET_ACCOUNT_ID")
  if [ $? -eq 0 ]; then
    echo "Found account $TARGET_ACCOUNT_ID in environment: $TARGET_ENV"
    setup_backend "$TARGET_ENV" "$TARGET_ACCOUNT_ID" "OrganizationAccountAccessRole"
    echo "Backend setup completed for account $TARGET_ACCOUNT_ID (environment: $TARGET_ENV)!"
  else
    echo "Error: Account ID $TARGET_ACCOUNT_ID not found in $ACCOUNTS_FILE"
    echo "Available accounts:"
    jq -r 'to_entries[] | "\(.key): \(.value.account_id)"' "$ACCOUNTS_FILE"
    exit 1
  fi
else
  # Process all environments (original behavior)
  echo "No account ID specified, processing all environments..."
  for env in $(jq -r 'keys[]' "$ACCOUNTS_FILE"); do
    account_id=$(jq -r ".${env}.account_id" "$ACCOUNTS_FILE")
    setup_backend "$env" "$account_id" "OrganizationAccountAccessRole"
  done
  echo "All backend configurations completed!"
fi