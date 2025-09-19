# Backend configuration for production environment
# Usage: terraform init -backend-config=shared/backend-prod.hcl
# This file gets automatically updated by setup-backend-per-account.sh script

bucket         = "REPLACE_WITH_ACTUAL_BUCKET_NAME"
key            = "environments/prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "REPLACE_WITH_ACTUAL_DYNAMODB_TABLE_NAME"
encrypt        = true

# Workspace configuration
workspace_key_prefix = "env"
skip_credentials_validation = false
skip_metadata_api_check = false
skip_region_validation = false
use_path_style = false

# Additional settings
max_retries = 5