# Terraform Infrastructure Orchestrator - Provider Configuration

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  # Cross-account assume role for deployment
  dynamic "assume_role" {
    for_each = var.account_id != null && var.account_id != "" && var.account_id != "345918514280" ? [1] : []
    content {
      role_arn     = "arn:aws:iam::${var.account_id}:role/OrganizationAccountAccessRole"
      session_name = "terraform-deployment-${var.environment}"
    }
  }

  # Ensure proper credential handling
  skip_credentials_validation = false
  skip_metadata_api_check     = false
  skip_region_validation      = false

  default_tags {
    tags = {
      Environment   = var.environment
      Project       = var.project_name
      ManagedBy     = "terraform"
      Workspace     = terraform.workspace
      OrgMaster     = "345918514280"
      TargetAccount = var.account_id
    }
  }
}