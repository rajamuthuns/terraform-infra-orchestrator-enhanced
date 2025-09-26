# Cross-Account Backend Configuration with Role Assumption
# Use this when running Terraform from a different account than the shared services account
# This config tells Terraform to assume a role to access the backend resources

bucket         = "terraform-state-central-multi-env"
key            = "terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks-common"
encrypt        = true

# Workspace configuration - creates separate state files per workspace
workspace_key_prefix = "environments"

# Standard S3 backend settings
skip_credentials_validation = false
skip_metadata_api_check = false
skip_region_validation = false
use_path_style = false
max_retries = 5