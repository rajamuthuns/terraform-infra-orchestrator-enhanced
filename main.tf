# Terraform Infrastructure Orchestrator - Main Configuration

# ALB Module
module "alb" {
  source =  "git::https://github.com/Norfolk-Southern/ns-itcp-tf-mod-alb.git"
  for_each = var.alb_spec

  vpc_id     = data.aws_vpc.selected[each.key].id
  subnet_ids = data.aws_subnets.public[each.key].ids

  http_enabled  = try(each.value.http_enabled, true)
  https_enabled = try(each.value.https_enabled, false)

  # SECURITY STRATEGY: CloudFront Prefix List (AWS Managed)
  # Use AWS managed CloudFront prefix list with increased security group quota
  # This provides CloudFront-only access with AWS managed IP ranges
  
  # ALB Security Groups - CloudFront Prefix List (AWS Managed)
  http_ingress_prefix_list_ids  = ["pl-3b927c52"]  # AWS CloudFront prefix list
  https_ingress_prefix_list_ids = ["pl-3b927c52"] # AWS CloudFront prefix list
  http_ingress_cidr_blocks      = []               # Empty when using prefix lists
  https_ingress_cidr_blocks     = []               # Empty when using prefix lists

  health_check_path    = try(each.value.health_check_path, "/")
  health_check_matcher = try(each.value.health_check_matcher, "200")

  target_group_port     = try(each.value.target_group_port, 80)
  target_group_protocol = try(each.value.target_group_protocol, "HTTP")

  certificate_arn = try(each.value.certificate_arn, "")

  load_balancer_name = "${each.key}-${var.environment}"
  target_group_name  = "${each.key}-${var.environment}-tg"

  name        = each.key
  environment = var.environment
  
  access_logs_enabled = false
  
  tags = merge(var.common_tags, try(each.value.tags, {}))
}

# WAF Module
module "waf" {
  source = "git::https://github.com/rajamuthuns/tf-waf-base-module.git?ref=main"

  for_each = var.waf_spec

  project     = var.project_name
  environment = var.environment
  scope       = each.value.scope

  default_action = try(each.value.default_action, "allow")

  enable_all_aws_managed_rules = try(each.value.enable_all_aws_managed_rules, false)
  enabled_aws_managed_rules    = try(each.value.enabled_aws_managed_rules, [])
  aws_managed_rule_overrides   = try(each.value.aws_managed_rule_overrides, {})
  custom_rules                 = try(each.value.custom_rules, [])

  ip_sets = {
    for k, v in try(each.value.ip_sets, {}) : k => {
      ip_version = try(v.ip_address_version, "IPV4") == "IPV4" ? "IPV4" : "IPV6"
      addresses  = v.addresses
    }
  }

  # No ALB associations needed - using CloudFront prefix list approach
  associated_resource_arns = []

  enable_logging     = try(each.value.enable_logging, false)
  log_retention_days = try(each.value.log_retention_days, 30)

  redacted_fields = [
    for field in try(each.value.redacted_fields, []) : {
      type = field.single_header != null ? "single_header" : (
        field.query_string != null ? "query_string" : "uri_path"
      )
      name = try(field.single_header.name, null)
    }
  ]

  tags = merge(var.common_tags, {
    Environment = var.environment
    Scope       = each.value.scope
  }, try(each.value.tags, {}))
}

# EC2 Module
module "ec2_instance" {
  source = "git::https://github.com/rajamuthuns/ec2-base-module.git?ref=main"
  for_each = var.ec2_spec

  name_prefix   = each.key
  vpc_name      = each.value.vpc_name
  environment   = var.environment
  account_id    = var.account_id
  instance_type = try(each.value.instance_type, "t3.small")
  key_name      = try(each.value.key_name, null)
  subnet_name   = try(each.value.subnet_name, null)

  ami_name = each.value.ami_name

  root_volume_size       = try(each.value.root_volume_size, try(each.value.os_type, "linux") == "windows" ? 50 : 20)
  additional_ebs_volumes = try(each.value.additional_ebs_volumes, [])

  enable_alb_integration = try(each.value.enable_alb_integration, false)
  alb_target_group_arns  = try(each.value.enable_alb_integration, false) ? [module.alb[each.value.alb_name].default_target_group_arn] : []

  ingress_rules = try(each.value.ingress_rules, [
    {
      from_port   = try(each.value.os_type, "linux") == "windows" ? 3389 : 22
      to_port     = try(each.value.os_type, "linux") == "windows" ? 3389 : 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
      description = try(each.value.os_type, "linux") == "windows" ? "RDP access from private networks" : "SSH access from private networks"
    }
  ])

  user_data = try(each.value.os_type, "linux") == "windows" ? base64encode(templatefile("${path.module}/userdata/userdata-windows.ps1", {
    environment = var.environment
    hostname    = each.key
    os_type     = "windows"
    })) : base64encode(templatefile("${path.module}/userdata/userdata-linux.sh", {
    environment = var.environment
    hostname    = each.key
    os_type     = try(each.value.os_type, "linux")
  }))

  create_security_group = true

  tags = merge({
    TestType = "EC2-Base-Module"
    Purpose  = "Infrastructure-Orchestrator"
  }, try(each.value.tags, {}))
}

# CloudFront Module
module "cloudfront" {
  source = "git::https://github.com/rajamuthuns/tf-cf-base-module.git?ref=main"

  for_each = var.cloudfront_spec

  distribution_name     = each.value.distribution_name
  origin_domain_name    = module.alb[each.value.alb_origin].alb_dns_name
  ping_auth_cookie_name = try(each.value.ping_auth_cookie_name, "PingAccessToken")
  ping_redirect_url     = each.value.ping_redirect_url

  allowed_methods = try(each.value.allowed_methods, ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"])
  cached_methods  = try(each.value.cached_methods, ["GET", "HEAD"])
  price_class     = try(each.value.price_class, "PriceClass_100")

  web_acl_id = try(each.value.waf_key, null) != null ? module.waf[each.value.waf_key].web_acl_arn : null

  tags = merge(var.common_tags, {
    Environment = var.environment
    Purpose     = "cloudfront-alb-integration"
    ALBOrigin   = each.value.alb_origin
  }, try(each.value.tags, {}))
}