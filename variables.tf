# Terraform Infrastructure Orchestrator - Variables
# This file defines all variables used across environments

# Project configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform-infra-orchestrator"
}

variable "gitlab_host" {
  description = "GitLab host for the private base modules"
  type        = string
  default     = "gitlab.aws.dev"
}

variable "gitlab_org" {
  description = "GitLab organization name for the private base modules"
  type        = string
}

variable "base_modules" {
  description = "Map of base modules with their repositories and versions"
  type = map(object({
    repository = string
    version    = string
  }))
}

variable "primary_module" {
  description = "Primary module to use for this deployment"
  type        = string
  default     = "ec2"
}

# AWS configuration
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "gitlab_token" {
  description = "GitLab token for module access"
  type        = string
  default     = ""
  sensitive   = true
}

# Common tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "terraform-infra-orchestrator"
    ManagedBy = "terraform"
    Owner     = "devops-team"
  }
}

# Module specifications
variable "ec2_spec" {
  description = "EC2 instance specifications"
  type        = any
  default     = {}
}

variable "alb_spec" {
  description = "ALB module specifications"
  type        = any
  default     = {}
}