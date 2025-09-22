# Shared Backend Configurations

This directory contains Terraform backend configuration files for each environment. These files are used to configure remote state storage in S3 with DynamoDB locking.

## Files

- **`backend-dev.hcl`** - Development environment backend configuration
- **`backend-staging.hcl`** - Staging environment backend configuration  
- **`backend-prod.hcl`** - Production environment backend configuration

## Automatic Setup

These files contain placeholder values that get automatically replaced when you run the backend setup script:

```bash
# Setup backend for specific account
./scripts/setup-backend-per-account.sh 221106935066

# Setup backends for all environments
./scripts/setup-backend-per-account.sh
```

## Before Setup (Placeholder Values)

```hcl
bucket         = "REPLACE_WITH_ACTUAL_BUCKET_NAME"
key            = "environments/dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "REPLACE_WITH_ACTUAL_DYNAMODB_TABLE_NAME"
encrypt        = true
```

## After Setup (Actual Values)

```hcl
bucket         = "terraform-state-dev-221106935066"
key            = "environments/dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-locks-dev"
encrypt        = true
```

## Usage

Once the backend is set up, initialize Terraform with the appropriate backend config:

```bash
# Development
terraform init -backend-config=shared/backend-dev.hcl

# Staging
terraform init -backend-config=shared/backend-staging.hcl

# Production
terraform init -backend-config=shared/backend-prod.hcl
```

## Workspace Isolation

Each environment uses its own:
- **S3 Bucket**: `terraform-state-{env}-{account-id}`
- **DynamoDB Table**: `terraform-state-locks-{env}`
- **Terraform Workspace**: `{env}` (dev, staging, production)

This ensures complete isolation between environments while sharing the same infrastructure code.

## Security Features

- **Encryption**: All state files are encrypted at rest
- **Versioning**: S3 bucket versioning is enabled for state history
- **Locking**: DynamoDB provides state locking to prevent concurrent modifications
- **Access Control**: Each environment uses separate AWS accounts for isolation