# Common Backend Configuration

This directory contains the common Terraform backend configuration used by all environments. The setup uses a single S3 bucket and DynamoDB table with Terraform workspaces for environment isolation.

## Files

- **`backend-common.hcl`** - Common backend configuration for all environments

## Governance Model

### **Platform Team Control**
- **Backend Location**: Controlled via `config/aws-accounts.json` (platform team manages this)
- **Shared Services Account**: Backend resources created in dedicated shared services account
- **Application Team Isolation**: App teams cannot accidentally create backend resources in wrong accounts
- **Centralized Management**: All backend resources managed by orchestrator/platform team

### **Application Team Responsibility**
- **Deployment Targets**: App teams specify target accounts in their `tfvars` files
- **Environment Configuration**: App teams manage environment-specific settings
- **No Backend Control**: App teams cannot control where backend resources are created

## Architecture Overview

```
Shared Services Account (Centralized Backend)
├── S3 Bucket: terraform-state-central-multi-env
│   ├── environments/
│   │   ├── dev/
│   │   │   └── terraform.tfstate
│   │   ├── staging/
│   │   │   └── terraform.tfstate
│   │   └── production/
│   │       └── terraform.tfstate
│
└── DynamoDB Table: terraform-state-locks-common
    └── Handles locking for all environments

Environment Accounts (Cross-Account Access)
├── Dev Account → Accesses shared backend
├── Staging Account → Accesses shared backend  
└── Production Account → Accesses shared backend
```

## Automatic Setup

Run the backend setup script to create the common resources and workspaces:

```bash
# Setup backend for specific account/environment
./scripts/setup-backend-per-account.sh 221106935066

# Setup backend for all environments
./scripts/setup-backend-per-account.sh
```

## Backend Configuration

The common backend configuration (`backend-common.hcl`):

```hcl
# Common backend configuration for all environments
bucket         = "terraform-state-central-multi-env"
key            = "terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks-common"
encrypt        = true

# Workspace configuration - creates separate state files per workspace
workspace_key_prefix = "environments"

skip_credentials_validation = false
skip_metadata_api_check = false
skip_region_validation = false
use_path_style = false
max_retries = 5
```

## Usage

### Initialize and Select Environment

```bash
# Initialize with common backend
terraform init -backend-config=shared/backend-common.hcl

# List available workspaces
terraform workspace list

# Select environment workspace
terraform workspace select dev
# or
terraform workspace select staging
# or  
terraform workspace select production

# Plan for current workspace
terraform plan -var-file=tfvars/$(terraform workspace show)-terraform.tfvars

# Apply for current workspace
terraform apply -var-file=tfvars/$(terraform workspace show)-terraform.tfvars
```

### Quick Environment Switch

```bash
# Switch to dev and plan
terraform workspace select dev
terraform plan -var-file=tfvars/dev-terraform.tfvars

# Switch to staging and plan
terraform workspace select staging
terraform plan -var-file=tfvars/stg-terraform.tfvars
```

## Workspace Isolation

Each environment uses:
- **Common S3 Bucket**: `terraform-state-central-multi-env`
- **Common DynamoDB Table**: `terraform-state-locks-common`
- **Separate State Files**: `environments/{workspace}/terraform.tfstate`
- **Terraform Workspace**: `dev`, `staging`, `production`

## Benefits

### Cost Optimization
- **Single S3 bucket** instead of 3+ separate buckets
- **Single DynamoDB table** instead of 3+ separate tables
- Reduced AWS resource management overhead

### Simplified Management
- One backend configuration for all environments
- Centralized state file location
- Easy to backup and monitor all environments

### Environment Isolation
- Workspaces provide complete state isolation
- Cross-account deployment maintains security boundaries
- Clear separation of environment resources

## Security Features

- **Encryption**: All state files are encrypted at rest with AES256
- **Versioning**: S3 bucket versioning enabled for state history
- **Locking**: DynamoDB provides state locking to prevent concurrent modifications
- **Cross-Account Access**: Bucket policy allows access from environment-specific AWS accounts
- **Access Control**: Each environment deploys to separate AWS accounts for isolation

## Troubleshooting

### Common Commands

```bash
# Check current workspace
terraform workspace show

# List all workspaces
terraform workspace list

# Create new workspace (if needed)
terraform workspace new <environment>

# Delete workspace (careful!)
terraform workspace delete <environment>

# Reinitialize backend
terraform init -reconfigure -backend-config=shared/backend-common.hcl
```

### State File Locations

State files are stored at these S3 paths:
- Dev: `s3://terraform-state-central-multi-env/environments/dev/terraform.tfstate`
- Staging: `s3://terraform-state-central-multi-env/environments/staging/terraform.tfstate`
- Production: `s3://terraform-state-central-multi-env/environments/production/terraform.tfstate`