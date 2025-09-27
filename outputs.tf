# Terraform Infrastructure Orchestrator - Outputs
# These outputs provide information about deployed resources across all environments

output "instance_details" {
  description = "Details of created EC2 instances"
  value = {
    for k, v in module.ec2_instance : k => {
      instance_id       = v.instance_id
      private_ip        = v.private_ip
      public_ip         = v.public_ip
      availability_zone = v.availability_zone
      subnet_id         = v.subnet_id
      vpc_id            = v.vpc_id
    }
  }
}

output "ami_information" {
  description = "AMI information for each instance"
  value = {
    for k, v in module.ec2_instance : k => v.ami_info
  }
}

output "security_groups" {
  description = "Security group information for each instance"
  value = {
    for k, v in module.ec2_instance : k => {
      security_group_id = v.security_group_id
    }
  }
}

output "ebs_volumes" {
  description = "EBS volume information for each instance"
  value = {
    for k, v in module.ec2_instance : k => {
      root_block_device  = v.root_block_device
      additional_volumes = v.additional_ebs_volumes
    }
  }
}

output "workspace_info" {
  description = "Current workspace information"
  value = {
    workspace   = terraform.workspace
    environment = var.environment
    region      = var.aws_region
  }
}

# ALB outputs for all ALB instances
output "alb_details" {
  description = "Details of all ALB instances"
  value = {
    for k, v in module.alb : k => {
      alb_dns_name             = v.alb_dns_name
      default_target_group_arn = v.default_target_group_arn
      vpc_id                   = v.vpc_id
      subnet_ids               = v.subnet_ids
      auto_discovered_subnets  = v.auto_discovered_subnets
      subnet_discovery_method  = v.subnet_discovery_method
    }
  }
}

# Environment-specific ALB endpoints
output "alb_endpoints" {
  description = "All ALB endpoints by name"
  value = {
    for k, v in module.alb : k => v.alb_dns_name
  }
}