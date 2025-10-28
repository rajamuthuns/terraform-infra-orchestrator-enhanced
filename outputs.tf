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

# CloudFront outputs
output "cloudfront_details" {
  description = "Details of all CloudFront distributions"
  value = {
    for k, v in module.cloudfront : k => {
      distribution_id     = v.distribution_id
      distribution_arn    = v.distribution_arn
      domain_name         = v.distribution_domain_name
      hosted_zone_id      = v.distribution_hosted_zone_id
      auth_function_arn   = v.auth_function_arn
    }
  }
}

output "cloudfront_endpoints" {
  description = "All CloudFront distribution endpoints"
  value = {
    for k, v in module.cloudfront : k => v.distribution_domain_name
  }
}

# WAF outputs
output "waf_details" {
  description = "Details of all WAF web ACLs"
  value = {
    for k, v in module.waf : k => {
      web_acl_id       = v.web_acl_id
      web_acl_arn      = v.web_acl_arn
      web_acl_name     = v.web_acl_name
      web_acl_capacity = v.web_acl_capacity
      ip_set_arns      = v.ip_set_arns
      deployment_info  = v.deployment_info
    }
  }
}



# Complete architecture flow summary
output "architecture_flow" {
  description = "Complete architecture flow: EC2 → ALB → CloudFront → WAF"
  value = {
    ec2_instances = {
      for k, v in module.ec2_instance : k => {
        instance_id = v.instance_id
        private_ip  = v.private_ip
        alb_integration = try(var.ec2_spec[k].enable_alb_integration, false) ? var.ec2_spec[k].alb_name : "none"
      }
    }
    alb_load_balancers = {
      for k, v in module.alb : k => {
        dns_name = v.alb_dns_name
        target_group_arn = v.default_target_group_arn
      }
    }
    cloudfront_distributions = {
      for k, v in module.cloudfront : k => {
        domain_name = v.distribution_domain_name
        origin_alb = try(var.cloudfront_spec[k].alb_origin, "unknown")
        waf_associated = try(var.cloudfront_spec[k].waf_key, null) != null
        waf_web_acl = try(var.cloudfront_spec[k].waf_key, null)
      }
    }
    waf_web_acls = {
      for k, v in module.waf : k => {
        web_acl_name = v.web_acl_name
        scope = try(var.waf_spec[k].scope, "REGIONAL")
        protected_resources = try(var.waf_spec[k].scope, "") == "CLOUDFRONT" ? try(var.waf_spec[k].protected_distributions, []) : try(var.waf_spec[k].protected_albs, [])
      }
    }
    cloudfront_waf_associations = {
      for k, v in var.cloudfront_spec : k => {
        cloudfront_distribution = k
        waf_web_acl = try(v.waf_key, null)
        associated = try(v.waf_key, null) != null
      } if try(v.waf_key, null) != null
    }
    waf_log_groups = {
      for k, v in module.waf : k => {
        name = v.log_group_name
        arn = v.log_group_arn
        retention_days = try(var.waf_spec[k].log_retention_days, 30)
      } if try(var.waf_spec[k].enable_logging, false)
    }

  }
}

# CloudWatch Log Groups for WAF
output "cloudwatch_log_groups" {
  description = "Details of CloudWatch log groups created for WAF logging"
  value = {
    for k, v in module.waf : k => {
      name           = v.log_group_name
      arn            = v.log_group_arn
      retention_days = try(var.waf_spec[k].log_retention_days, 30)
    } if try(var.waf_spec[k].enable_logging, false)
  }
}

# CloudFront Security Configuration Details
output "cloudfront_security_config" {
  description = "Details about CloudFront IP access control configuration"
  value = {
    access_control_method = "managed_prefix_list"
    managed_prefix_list_available = true
    managed_prefix_list_id = local.cloudfront_prefix_list_id
    prefix_list_entries = "46 CloudFront IP ranges"
    security_approach = "Using AWS managed prefix list for complete CloudFront coverage"
  }
}