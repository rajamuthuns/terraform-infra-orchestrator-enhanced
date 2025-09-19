# Backend configuration for Terraform state management
# This file defines the S3 backend configuration for remote state storage

terraform {
  backend "s3" {
    # Backend configuration will be provided via backend config files
    # located in the shared/ directory for each environment:
    # - shared/backend-dev.hcl
    # - shared/backend-staging.hcl  
    # - shared/backend-prod.hcl
    #
    # Usage:
    # terraform init -backend-config=shared/backend-dev.hcl
  }
}