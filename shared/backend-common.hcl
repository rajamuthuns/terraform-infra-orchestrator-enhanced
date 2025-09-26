# Common backend configuration for all environments
# Usage: terraform init -backend-config=shared/backend-common.hcl
# Workspaces will handle environment separation

bucket         = "terraform-state-central-multi-env"
key            = "terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks-common"
encrypt        = true

# Workspace configuration - this creates separate state files per workspace
workspace_key_prefix = "environments"

# Standard S3 backend settings
skip_credentials_validation = false
skip_metadata_api_check = false
skip_region_validation = false
use_path_style = false
max_retries = 5