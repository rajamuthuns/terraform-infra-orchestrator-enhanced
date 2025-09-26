# Backend configuration for Terraform state management
# This file defines the S3 backend configuration for remote state storage
# Uses a single common backend with workspace isolation for all environments

terraform {
  backend "s3" {
    # Backend configuration will be provided via the common backend config file:
    # - shared/backend-common.hcl (used by all environments)
    #
    # Workspaces provide environment isolation:
    # - dev workspace: environments/dev/terraform.tfstate
    # - staging workspace: environments/staging/terraform.tfstate  
    # - production workspace: environments/production/terraform.tfstate
    #
    # Usage:
    # terraform init -backend-config=shared/backend-common.hcl
    # terraform workspace select <environment>
  }
}