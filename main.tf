# Terraform Infrastructure Orchestrator - Main Configuration
# This file orchestrates multiple base modules and is environment-agnostic

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
  # Credential flow:
  # 1. Workflow uses org master account (345918514280) credentials
  # 2. Backend operations: workflow assumes shared services account (852998999082) role for state/locking
  # 3. Provider operations: provider assumes target deployment account role (if different from org master)
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

# Data source to get CloudFront IP ranges
data "aws_ip_ranges" "cloudfront" {
  regions  = ["global"]
  services = ["cloudfront"]
}



# ALB Module - Application Load Balancer with CloudFront IP restriction
module "alb" {
  source = "https://github.com/purushothamgk-ns/tf-alb.git?ref=main"

  for_each = var.alb_spec

  # VPC configuration - use vpc_name for automatic discovery
  vpc_name = each.value.vpc_name
  
  # Auto-discover public subnets
  auto_discover_public_subnets = true

  # Basic ALB settings
  http_enabled  = each.value.http_enabled
  https_enabled = each.value.https_enabled

  # CloudFront IP restriction - Only allow CloudFront IPs to access ALB
  http_ingress_cidr_blocks  = data.aws_ip_ranges.cloudfront.cidr_blocks
  https_ingress_cidr_blocks = data.aws_ip_ranges.cloudfront.cidr_blocks

  # Health check configuration
  health_check_path    = try(each.value.health_check_path, "/")
  health_check_matcher = try(each.value.health_check_matcher, "200")

  # Certificate for HTTPS
  certificate_arn = try(each.value.certificate_arn, "")

  # Force destroy S3 bucket for ALB logs
  alb_access_logs_s3_bucket_force_destroy = true
}

# EC2 Module - Elastic Compute Cloud instances
module "ec2_instance" {
  source   = "git::https://github.com/rajamuthuns/ec2-base-module.git?ref=main"
  for_each = var.ec2_spec

  name_prefix   = each.key
  vpc_name      = each.value.vpc_name
  environment   = var.environment
  account_id    = var.account_id
  instance_type = try(each.value.instance_type, "t3.small")
  key_name      = try(each.value.key_name, null)
  subnet_name   = try(each.value.subnet_name, null)

  # Use AMI name (required)
  ami_name = each.value.ami_name

  # OS-specific configurations
  root_volume_size       = try(each.value.root_volume_size, try(each.value.os_type, "linux") == "windows" ? 50 : 20)
  additional_ebs_volumes = try(each.value.additional_ebs_volumes, [])

  # ALB Integration - Connect to ALB target groups
  enable_alb_integration = try(each.value.enable_alb_integration, false)
  alb_target_group_arns  = try(each.value.enable_alb_integration, false) ? [module.alb[each.value.alb_name].default_target_group_arn] : []

  # OS-specific security group rules
  ingress_rules = try(each.value.ingress_rules, [
    {
      from_port   = try(each.value.os_type, "linux") == "windows" ? 3389 : 22
      to_port     = try(each.value.os_type, "linux") == "windows" ? 3389 : 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
      description = try(each.value.os_type, "linux") == "windows" ? "RDP access from private networks" : "SSH access from private networks"
    }
  ])

  # OS-specific user data
  user_data = try(each.value.os_type, "linux") == "windows" ? base64encode(templatefile("${path.module}/userdata/userdata-windows.ps1", {
    environment = var.environment
    hostname    = each.key
    os_type     = "windows"
    })) : base64encode(templatefile("${path.module}/userdata/userdata-linux.sh", {
    environment = var.environment
    hostname    = each.key
    os_type     = try(each.value.os_type, "linux")
  }))

  # Use existing security group or create new one
  create_security_group = true

  tags = merge({
    TestType = "EC2-Base-Module"
    Purpose  = "Infrastructure-Orchestrator"
  }, try(each.value.tags, {}))
}




# WAF - Web Application Firewall (created before CloudFront)
module "waf" {
  source = "git::https://github.com/rajamuthuns/tf-waf-base-module.git?ref=main"

  for_each = var.waf_spec

  # Basic configuration
  project     = var.project_name
  environment = var.environment
  scope       = each.value.scope # CLOUDFRONT for CloudFront, REGIONAL for ALB

  # WAF rules configuration
  enable_all_aws_managed_rules = try(each.value.enable_all_aws_managed_rules, false)
  enabled_aws_managed_rules    = try(each.value.enabled_aws_managed_rules, [])
  aws_managed_rule_overrides   = try(each.value.aws_managed_rule_overrides, {})
  custom_rules                 = try(each.value.custom_rules, [])

  # IP sets - Convert from tfvars format to module format
  ip_sets = {
    for k, v in try(each.value.ip_sets, {}) : k => {
      ip_version = try(v.ip_address_version, "IPV4") == "IPV4" ? "IPV4" : "IPV6"
      addresses  = v.addresses
    }
  }

  # Resource associations - CloudFront associations handled separately
  # Note: For CloudFront scope, associations are not handled through this parameter
  # CloudFront-WAF integration requires updating the CloudFront distribution configuration
  associated_resource_arns = each.value.scope == "REGIONAL" ? [
    for alb_key in try(each.value.protected_albs, []) : module.alb[alb_key].alb_arn
  ] : []

  # Logging configuration - Log group created automatically by module
  enable_logging     = try(each.value.enable_logging, false)
  log_retention_days = try(each.value.log_retention_days, 30)
  
  # Redacted fields - Convert from tfvars format to module format
  redacted_fields = [
    for field in try(each.value.redacted_fields, []) : {
      type = field.single_header != null ? "single_header" : (
        field.query_string != null ? "query_string" : "uri_path"
      )
      name = try(field.single_header.name, null)
    }
  ]

  # Tags
  tags = merge(var.common_tags, {
    Environment = var.environment
    Scope       = each.value.scope
  }, try(each.value.tags, {}))
}

# CloudFront Distribution - Linked to ALB origins
module "cloudfront" {
  source = "git::https://github.com/rajamuthuns/tf-cf-base-module.git?ref=main"

  for_each = var.cloudfront_spec

  distribution_name     = each.value.distribution_name
  origin_domain_name    = module.alb[each.value.alb_origin].alb_dns_name
  ping_auth_cookie_name = try(each.value.ping_auth_cookie_name, "PingAccessToken")
  ping_redirect_url     = each.value.ping_redirect_url

  # CloudFront module supported parameters
  allowed_methods = try(each.value.allowed_methods, ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"])
  cached_methods  = try(each.value.cached_methods, ["GET", "HEAD"])
  price_class     = try(each.value.price_class, "PriceClass_100")

  # WAF Web ACL association - reference WAF module output
  web_acl_id = try(each.value.waf_key, null) != null ? module.waf[each.value.waf_key].web_acl_arn : null

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "cloudfront-alb-integration"
    ALBOrigin   = each.value.alb_origin
  }, try(each.value.tags, {}))
}

