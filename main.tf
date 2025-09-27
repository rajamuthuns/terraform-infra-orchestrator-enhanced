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
  # Backend operations stay in org master/shared services account
  # Resource operations assume role in target account
  dynamic "assume_role" {
    for_each = var.account_id != null && var.account_id != "" ? [1] : []
    content {
      role_arn     = "arn:aws:iam::${var.account_id}:role/OrganizationAccountAccessRole"
      session_name = "terraform-deployment-${var.environment}"
    }
  }

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
      Workspace   = terraform.workspace
    }
  }
}

# ALB Module - Application Load Balancer
module "alb" {
  source = "git::https://github.com/purushothamgk-ns/tf-alb.git"

  for_each = var.alb_spec

  # Required: VPC name (must match Name tag on your VPC)
  vpc_name = each.value.vpc_name

  # Optional: Basic ALB settings
  http_enabled  = each.value.http_enabled
  https_enabled = each.value.https_enabled

  # Optional: Certificate for HTTPS (uncomment if needed)
  # certificate_arn = each.value.certificate_arn

  # Optional: Naming context
  namespace   = each.key
  environment = var.environment
  name        = each.value.name
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