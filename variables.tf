# Terraform Infrastructure Orchestrator - Variables
# This file defines all variables used across environments

# Project configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "terraform-infra-orchestrator"
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

# Module specifications - All configurations come from tfvars
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

variable "cloudfront_spec" {
  description = "CloudFront distribution specifications"
  type        = any
  default     = {}
}

variable "waf_spec" {
  description = "WAF configuration specifications"
  type        = any
  default     = {}
}

