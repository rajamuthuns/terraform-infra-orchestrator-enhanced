#!/bin/bash

# Automated Backend Setup for Multi-Account Deployment with Single S3 Bucket
# This script creates a single common S3 bucket and DynamoDB table for all environments
# Uses Terraform workspaces for environment isolation
# Usage: ./setup-backend-per-account.sh [ACCOUNT_ID]
# If no ACCOUNT_ID provided, processes all environments

set -e

# Read account configuration
ACCOUNTS_FILE="config/aws-accounts.json"

if [ ! -f "$ACCOUNTS_FILE" ]; then
  echo "Error: $ACCOUNTS_FILE not found"
  exit 1
fi

# Common backend resources (single bucket for all environments)
COMMON_BUCKET_NAME="terraform-state-central-multi-env"
COMMON_DYNAMODB_TABLE="terraform-state-locks-common"

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

# Validate prerequisites
validate_prerequisites() {
  echo "🔍 Validating prerequisites..."
  
  # Check if required tools are installed
  if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed or not in PATH"
    exit 1
  fi
  
  if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed or not in PATH"
    exit 1
  fi
  
  if ! command -v jq &> /dev/null; then
    echo "❌ jq is not installed or not in PATH"
    exit 1
  fi
  
  # Check if we're in the right directory
  if [ ! -f "main.tf" ] && [ ! -f "backend.tf" ]; then
    echo "❌ This doesn't appear to be a Terraform project directory"
    echo "Make sure you're running this script from the root of your Terraform project"
    exit 1
  fi
  
  # Check AWS credentials
  if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured or invalid"
    echo "Please configure AWS credentials using 'aws configure' or environment variables"
    exit 1
  fi
  
  echo "✅ Prerequisites validated"
}

# Note: This script now uses a common backend approach
# No need to store original credentials since we don't switch accounts

# Function to setup common backend resources (run once)
setup_common_backend() {
  echo "🔧 Setting up common backend resources in shared services account"
  
  # Get shared services account ID from config (controlled by platform team)
  SHARED_SERVICES_ACCOUNT_ID=$(jq -r '.shared_services.account_id' "$ACCOUNTS_FILE")
  
  if [ "$SHARED_SERVICES_ACCOUNT_ID" = "null" ] || [ "$SHARED_SERVICES_ACCOUNT_ID" = "REPLACE_WITH_SHARED_SERVICES_ACCOUNT_ID" ]; then
    echo "❌ Shared services account ID not configured in $ACCOUNTS_FILE"
    echo "Please update the shared_services.account_id field with the actual shared services account ID"
    echo "This ensures backend resources are created in the correct account controlled by the platform team"
    exit 1
  fi
  
  echo "📋 Shared Services Account (for backend): $SHARED_SERVICES_ACCOUNT_ID"
  echo "🏛️ This account is controlled by the platform/orchestrator team"
  
  # Assume role in shared services account for backend resources
  SHARED_SERVICES_ROLE_ARN="arn:aws:iam::${SHARED_SERVICES_ACCOUNT_ID}:role/OrganizationAccountAccessRole"
  
  echo "🔐 Assuming role in shared services account: $SHARED_SERVICES_ROLE_ARN"
  if SHARED_CREDENTIALS=$(aws sts assume-role \
    --role-arn "$SHARED_SERVICES_ROLE_ARN" \
    --role-session-name "backend-setup-shared-services" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text 2>&1); then
    
    export AWS_ACCESS_KEY_ID=$(echo $SHARED_CREDENTIALS | cut -d' ' -f1)
    export AWS_SECRET_ACCESS_KEY=$(echo $SHARED_CREDENTIALS | cut -d' ' -f2)
    export AWS_SESSION_TOKEN=$(echo $SHARED_CREDENTIALS | cut -d' ' -f3)
    echo "✅ Successfully assumed role in shared services account"
  else
    echo "❌ Failed to assume role in shared services account"
    echo "Error: $SHARED_CREDENTIALS"
    echo "Please ensure:"
    echo "1. The shared services account ID is correct in $ACCOUNTS_FILE"
    echo "2. OrganizationAccountAccessRole exists in the shared services account"
    echo "3. Current credentials have permission to assume the role"
    exit 1
  fi
  
  # Create common S3 bucket (in management account)
  echo "Creating common S3 bucket: $COMMON_BUCKET_NAME"
  if aws s3api head-bucket --bucket "$COMMON_BUCKET_NAME" 2>/dev/null; then
    echo "Common bucket $COMMON_BUCKET_NAME already exists"
  else
    aws s3api create-bucket --bucket "$COMMON_BUCKET_NAME" --region us-east-1
    aws s3api put-bucket-versioning --bucket "$COMMON_BUCKET_NAME" --versioning-configuration Status=Enabled
    aws s3api put-bucket-encryption --bucket "$COMMON_BUCKET_NAME" --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'
    aws s3api put-public-access-block --bucket "$COMMON_BUCKET_NAME" --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    echo "Setting up cross-account bucket policy..."
  fi
  
  # Always update bucket policy (whether bucket is new or existing)
  echo "Updating bucket policy for cross-account access..."
  
  # Build list of account ARNs for cross-account access
  ACCOUNT_ARNS="\"arn:aws:iam::${SHARED_SERVICES_ACCOUNT_ID}:root\""
  
  # Add environment accounts with OrganizationAccountAccessRole
  for env in $(jq -r 'keys[]' "$ACCOUNTS_FILE"); do
    # Skip shared_services entry
    if [ "$env" = "shared_services" ]; then
      continue
    fi
    
    account_id=$(jq -r ".${env}.account_id" "$ACCOUNTS_FILE")
    if [ "$account_id" != "null" ] && [ "$account_id" != "REPLACE_WITH_PRODUCTION_ACCOUNT_ID" ] && [ "$account_id" != "REPLACE_WITH_SHARED_SERVICES_ACCOUNT_ID" ]; then
      ACCOUNT_ARNS="${ACCOUNT_ARNS},\"arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole\""
      # Also add root access for the account (for broader access patterns)
      ACCOUNT_ARNS="${ACCOUNT_ARNS},\"arn:aws:iam::${account_id}:root\""
      echo "  - Added access for $env account: $account_id (via OrganizationAccountAccessRole and root)"
    fi
  done
  
  # Add current user/account for administrative access
  CURRENT_USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
  CURRENT_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  ACCOUNT_ARNS="${ACCOUNT_ARNS},\"${CURRENT_USER_ARN}\""
  ACCOUNT_ARNS="${ACCOUNT_ARNS},\"arn:aws:iam::${CURRENT_ACCOUNT_ID}:root\""
  echo "  - Added access for current user: $CURRENT_USER_ARN"
  echo "  - Added access for current account: $CURRENT_ACCOUNT_ID"
  
  # Apply comprehensive bucket policy for cross-account and cross-region access
  aws s3api put-bucket-policy --bucket "$COMMON_BUCKET_NAME" --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Sid\": \"AllowCrossAccountAccess\",
        \"Effect\": \"Allow\",
        \"Principal\": {
          \"AWS\": [${ACCOUNT_ARNS}]
        },
        \"Action\": [
          \"s3:GetObject\",
          \"s3:PutObject\",
          \"s3:DeleteObject\",
          \"s3:ListBucket\",
          \"s3:GetBucketLocation\",
          \"s3:ListBucketVersions\",
          \"s3:GetBucketVersioning\",
          \"s3:PutBucketVersioning\"
        ],
        \"Resource\": [
          \"arn:aws:s3:::${COMMON_BUCKET_NAME}\",
          \"arn:aws:s3:::${COMMON_BUCKET_NAME}/*\"
        ]
      }
    ]
  }"
  
  echo "✅ Bucket policy updated with shared services account and environment accounts"
  echo "📋 Accounts with access:"
  echo "   - Shared Services Account: $SHARED_SERVICES_ACCOUNT_ID (full access)"
  for env in $(jq -r 'keys[]' "$ACCOUNTS_FILE"); do
    if [ "$env" != "shared_services" ]; then
      account_id=$(jq -r ".${env}.account_id" "$ACCOUNTS_FILE")
      if [ "$account_id" != "null" ] && [ "$account_id" != "REPLACE_WITH_PRODUCTION_ACCOUNT_ID" ]; then
        echo "   - $env Account: $account_id (via OrganizationAccountAccessRole)"
      fi
    fi
  done
  fi
  
  # Create common DynamoDB table (in shared services account)
  echo "Creating common DynamoDB table: $COMMON_DYNAMODB_TABLE"
  if aws dynamodb describe-table --table-name "$COMMON_DYNAMODB_TABLE" 2>/dev/null; then
    echo "Common table $COMMON_DYNAMODB_TABLE already exists"
  else
    aws dynamodb create-table \
      --table-name "$COMMON_DYNAMODB_TABLE" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --sse-specification Enabled=true
    
    # Wait for table to be active before applying resource policy
    echo "Waiting for DynamoDB table to become active..."
    aws dynamodb wait table-exists --table-name "$COMMON_DYNAMODB_TABLE"
  fi
  
  # Apply DynamoDB resource policy for cross-account access
  echo "Setting up DynamoDB resource policy for cross-account access..."
  
  # Build list of account ARNs for DynamoDB access (similar to S3 but for DynamoDB)
  DYNAMODB_ACCOUNT_ARNS="\"arn:aws:iam::${SHARED_SERVICES_ACCOUNT_ID}:root\""
  
  # Add all accounts (including org_master for pipeline access)
  for env in $(jq -r 'keys[]' "$ACCOUNTS_FILE"); do
    if [ "$env" != "shared_services" ]; then
      account_id=$(jq -r ".${env}.account_id" "$ACCOUNTS_FILE")
      if [ "$account_id" != "null" ] && [ "$account_id" != "REPLACE_WITH_PRODUCTION_ACCOUNT_ID" ] && [ "$account_id" != "REPLACE_WITH_SHARED_SERVICES_ACCOUNT_ID" ]; then
        DYNAMODB_ACCOUNT_ARNS="${DYNAMODB_ACCOUNT_ARNS},\"arn:aws:iam::${account_id}:role/OrganizationAccountAccessRole\""
        DYNAMODB_ACCOUNT_ARNS="${DYNAMODB_ACCOUNT_ARNS},\"arn:aws:iam::${account_id}:root\""
        echo "  - Added DynamoDB access for $env account: $account_id"
      fi
    fi
  done
  
  # Add current user/account for administrative access
  CURRENT_USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
  CURRENT_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  DYNAMODB_ACCOUNT_ARNS="${DYNAMODB_ACCOUNT_ARNS},\"${CURRENT_USER_ARN}\""
  DYNAMODB_ACCOUNT_ARNS="${DYNAMODB_ACCOUNT_ARNS},\"arn:aws:iam::${CURRENT_ACCOUNT_ID}:root\""
  
  # Apply DynamoDB resource policy
  aws dynamodb put-resource-policy \
    --resource-arn "arn:aws:dynamodb:us-east-1:${SHARED_SERVICES_ACCOUNT_ID}:table/${COMMON_DYNAMODB_TABLE}" \
    --policy "{
      \"Version\": \"2012-10-17\",
      \"Statement\": [
        {
          \"Sid\": \"AllowCrossAccountDynamoDBAccess\",
          \"Effect\": \"Allow\",
          \"Principal\": {
            \"AWS\": [${DYNAMODB_ACCOUNT_ARNS}]
          },
          \"Action\": [
            \"dynamodb:GetItem\",
            \"dynamodb:PutItem\",
            \"dynamodb:DeleteItem\",
            \"dynamodb:DescribeTable\"
          ],
          \"Resource\": \"arn:aws:dynamodb:us-east-1:${SHARED_SERVICES_ACCOUNT_ID}:table/${COMMON_DYNAMODB_TABLE}\"
        }
      ]
    }" 2>/dev/null || {
    echo "⚠️ DynamoDB resource policy not supported in this region or account"
    echo "💡 Alternative: Ensure OrganizationAccountAccessRole in environment accounts has DynamoDB permissions"
    echo "   Required permissions: dynamodb:GetItem, dynamodb:PutItem, dynamodb:DeleteItem, dynamodb:DescribeTable"
    echo "   Resource: arn:aws:dynamodb:us-east-1:${SHARED_SERVICES_ACCOUNT_ID}:table/${COMMON_DYNAMODB_TABLE}"
  }
  
  echo "✅ Common backend resources setup completed"
}

# Function to setup workspace for an environment
setup_environment_workspace() {
  local env=$1
  local account_id=$2
  
  echo "🏢 Setting up workspace for environment: $env (Account: $account_id)"
  
  # Create common backend configuration file (same for all environments)
  cat > "shared/backend-common.hcl" << EOF
# Common backend configuration for all environments
# Workspaces handle environment separation
bucket         = "${COMMON_BUCKET_NAME}"
key            = "terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "${COMMON_DYNAMODB_TABLE}"
encrypt        = true

# Workspace configuration - creates separate state files per workspace
workspace_key_prefix = "environments"

skip_credentials_validation = false
skip_metadata_api_check = false
skip_region_validation = false
use_path_style = false
max_retries = 5
EOF
  
  # Initialize Terraform with common backend
  echo "Initializing Terraform with common backend..."
  if ! terraform init -backend-config="shared/backend-common.hcl"; then
    echo "❌ Failed to initialize Terraform with common backend"
    echo "Make sure you're running this from the root of your Terraform project"
    exit 1
  fi
  
  # Create workspace if it doesn't exist
  echo "Setting up workspace '$env'..."
  if terraform workspace list 2>/dev/null | grep -q "^\s*${env}\s*$"; then
    echo "Workspace '$env' already exists, selecting it"
    terraform workspace select "$env"
  else
    echo "Creating new workspace '$env'"
    if ! terraform workspace new "$env"; then
      echo "❌ Failed to create workspace '$env'"
      exit 1
    fi
  fi
  
  echo "✅ Terraform workspace '$env' is ready"
  echo "📦 Using common bucket: $COMMON_BUCKET_NAME"
  echo "🗄️ Using common DynamoDB: $COMMON_DYNAMODB_TABLE"
  echo "🏢 Workspace: $env"
  echo "📍 State file location: environments/$env/terraform.tfstate"
  echo ""
}

# Validate prerequisites before starting
validate_prerequisites

# Setup common backend resources first (only needs to run once)
echo "🚀 Starting common backend setup for all environments..."
setup_common_backend

# Process environments based on input
if [ -n "$TARGET_ACCOUNT_ID" ]; then
  # Process only the environment for the specified account
  echo "Looking for environment with account ID: $TARGET_ACCOUNT_ID"
  
  TARGET_ENV=$(find_environment_for_account "$TARGET_ACCOUNT_ID")
  if [ $? -eq 0 ]; then
    echo "Found account $TARGET_ACCOUNT_ID in environment: $TARGET_ENV"
    setup_environment_workspace "$TARGET_ENV" "$TARGET_ACCOUNT_ID"
    echo "✅ Backend setup completed for account $TARGET_ACCOUNT_ID (environment: $TARGET_ENV)!"
  else
    echo "❌ Error: Account ID $TARGET_ACCOUNT_ID not found in $ACCOUNTS_FILE"
    echo "Available accounts:"
    jq -r 'to_entries[] | "\(.key): \(.value.account_id)"' "$ACCOUNTS_FILE"
    exit 1
  fi
else
  # Process all environments (original behavior)
  echo "No account ID specified, processing all environments..."
  PROCESSED_COUNT=0
  SKIPPED_COUNT=0
  
  for env in $(jq -r 'keys[]' "$ACCOUNTS_FILE"); do
    account_id=$(jq -r ".${env}.account_id" "$ACCOUNTS_FILE")
    if [ "$account_id" != "null" ] && [ "$account_id" != "REPLACE_WITH_PRODUCTION_ACCOUNT_ID" ]; then
      setup_environment_workspace "$env" "$account_id"
      PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    else
      echo "⚠️ Skipping $env - account ID not configured (value: $account_id)"
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
  done
  
  echo "✅ All backend configurations completed!"
  echo "📊 Summary: $PROCESSED_COUNT environments processed, $SKIPPED_COUNT skipped"
fi

echo ""
echo "🎉 Backend setup summary:"
echo "📦 Common S3 Bucket: $COMMON_BUCKET_NAME (in shared services account)"
echo "🗄️ Common DynamoDB Table: $COMMON_DYNAMODB_TABLE (in shared services account)"
echo "🏢 Workspaces created for environment isolation"
echo "📍 State files will be stored as: environments/{workspace}/terraform.tfstate"
echo "🔐 Shared Services Account: $SHARED_SERVICES_ACCOUNT_ID"
echo ""
echo "🔄 Note: If you add new environments to config/aws-accounts.json later,"
echo "   just run this script again to update the bucket policy and create workspaces."
echo ""
echo "💡 To use this setup:"
echo "   terraform init -backend-config=shared/backend-common.hcl"
echo "   terraform workspace select {environment}"
echo ""
echo "🔧 Useful commands:"
echo "   # List all workspaces:"
echo "   terraform workspace list"
echo ""
echo "   # Switch to a specific environment:"
echo "   terraform workspace select dev"
echo ""
echo "   # Plan for current workspace:"
echo "   terraform plan -var-file=tfvars/\$(terraform workspace show)-terraform.tfvars"