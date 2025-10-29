# Terraform Infrastructure Orchestrator - Outputs

# Essential Infrastructure Endpoints
output "alb_endpoints" {
  description = "ALB endpoints for accessing applications"
  value = {
    for k, v in module.alb : k => "http://${v.alb_dns_name}"
  }
}

output "cloudfront_endpoints" {
  description = "CloudFront distribution endpoints"
  value = {
    for k, v in module.cloudfront : k => "https://${v.distribution_domain_name}"
  }
}

# Instance Information
output "instance_details" {
  description = "EC2 instance details"
  value = {
    for k, v in module.ec2_instance : k => {
      instance_id = v.instance_id
      private_ip  = v.private_ip
      public_ip   = v.public_ip
    }
  }
}

# Architecture Flow Summary
output "architecture_flow" {
  description = "Complete architecture flow: EC2 → ALB → CloudFront → WAF"
  value = {
    ec2_instances = {
      for k, v in module.ec2_instance : k => {
        instance_id = v.instance_id
        alb_integration = try(var.ec2_spec[k].enable_alb_integration, false) ? var.ec2_spec[k].alb_name : "none"
      }
    }
    alb_load_balancers = {
      for k, v in module.alb : k => {
        dns_name = v.alb_dns_name
      }
    }
    cloudfront_distributions = {
      for k, v in module.cloudfront : k => {
        domain_name = v.distribution_domain_name
        origin_alb = try(var.cloudfront_spec[k].alb_origin, "unknown")
        waf_protected = try(var.cloudfront_spec[k].waf_key, null) != null
      }
    }
    waf_web_acls = {
      for k, v in module.waf : k => {
        web_acl_name = v.web_acl_name
        scope = try(var.waf_spec[k].scope, "REGIONAL")
      }
    }
  }
}

# Environment Information
output "deployment_info" {
  description = "Current deployment information"
  value = {
    workspace   = terraform.workspace
    environment = var.environment
    region      = var.aws_region
  }
}

# Security Configuration
output "waf_details" {
  description = "WAF web ACL details"
  value = {
    for k, v in module.waf : k => {
      web_acl_id   = v.web_acl_id
      web_acl_name = v.web_acl_name
      capacity     = v.web_acl_capacity
    }
  }
}