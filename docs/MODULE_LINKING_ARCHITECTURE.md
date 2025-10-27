# Module Linking Architecture

## Overview
This document describes the complete architecture flow: **EC2 → ALB → CloudFront → WAF**

## Architecture Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│     EC2     │───▶│     ALB     │───▶│ CloudFront  │───▶│     WAF     │
│ Instances   │    │Load Balancer│    │Distribution │    │Web ACL      │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## Module Specifications

### 1. EC2 Module
- **Purpose**: Application servers (Linux and Windows)
- **Integration**: Connected to ALB target groups via `alb_target_group_arns`
- **Configuration**: 
  - `enable_alb_integration = true`
  - `alb_name` references the ALB module key

### 2. ALB Module
- **Purpose**: Load balancing between EC2 instances
- **Integration**: Provides `alb_dns_name` as origin for CloudFront
- **Configuration**: Two ALBs (linux-alb, windows-alb) for different application stacks

### 3. CloudFront Module
- **Purpose**: Global content delivery and caching
- **Integration**: 
  - `origin_domain_name` = `module.alb[each.value.alb_origin].alb_dns_name`
  - Protected by WAF via `distribution_arn`
- **Configuration**: Separate distributions for Linux and Windows applications

### 4. WAF Module
- **Purpose**: Web application firewall protection
- **Integration**: 
  - `associated_resource_arns` = CloudFront distribution ARNs
  - `scope = "CLOUDFRONT"` for CloudFront protection
- **Configuration**: Single WAF protecting both CloudFront distributions

## Configuration Structure

### CloudFront Specification
```hcl
cloudfront_spec = {
  linux-cf = {
    distribution_name      = "linux-app-distribution"
    alb_origin            = "linux-alb"  # References ALB module key
    price_class           = "PriceClass_100"
    viewer_protocol_policy = "redirect-to-https"
    origin_protocol_policy = "http-only"
    # ... additional configurations
  }
}
```

### WAF Specification
```hcl
waf_spec = {
  cloudfront-waf = {
    scope = "CLOUDFRONT"
    protected_distributions = ["linux-cf", "windows-cf"]  # References CloudFront keys
    enabled_aws_managed_rules = [
      "AWSManagedRulesCommonRuleSet",
      "AWSManagedRulesKnownBadInputsRuleSet",
      # ... additional rules
    ]
    # ... additional configurations
  }
}
```

## Environment-Specific Configurations

### Development
- **CloudFront**: Basic caching, HTTP allowed
- **WAF**: Basic protection, rate limiting (2000 req/5min)
- **Logging**: Basic WAF logging enabled

### Staging
- **CloudFront**: Enhanced caching, HTTPS redirect
- **WAF**: Enhanced protection, geo-blocking, stricter rate limiting (1000 req/5min)
- **Logging**: Comprehensive logging

### Production
- **CloudFront**: Global distribution, HTTPS only
- **WAF**: Maximum protection, bot control, size restrictions, strict rate limiting (500 req/5min)
- **Logging**: Full logging with field redaction

## Resource Dependencies

```
EC2 Instances
    ↓ (depends on ALB target groups)
ALB Load Balancers
    ↓ (provides DNS name as origin)
CloudFront Distributions
    ↓ (provides ARN for protection)
WAF Web ACLs
```

## Key Reference Values

### EC2 → ALB Integration
```hcl
# In EC2 specification
enable_alb_integration = true
alb_name = "linux-alb"  # References alb_spec key

# Terraform resolves to:
alb_target_group_arns = [module.alb["linux-alb"].default_target_group_arn]
```

### ALB → CloudFront Integration
```hcl
# In CloudFront specification
alb_origin = "linux-alb"  # References alb_spec key

# Terraform resolves to:
origin_domain_name = module.alb["linux-alb"].alb_dns_name
```

### CloudFront → WAF Integration
```hcl
# In WAF specification
protected_distributions = ["linux-cf", "windows-cf"]  # References cloudfront_spec keys

# Terraform resolves to:
associated_resource_arns = [
  module.cloudfront["linux-cf"].distribution_arn,
  module.cloudfront["windows-cf"].distribution_arn
]
```

## Deployment Order

1. **EC2 and ALB**: Can be deployed in parallel
2. **CloudFront**: Deployed after ALB (needs ALB DNS name)
3. **WAF**: Deployed after CloudFront (needs distribution ARNs)

## Outputs

The configuration provides comprehensive outputs showing the complete architecture flow:

```hcl
output "architecture_flow" {
  value = {
    ec2_instances = { /* EC2 details with ALB integration */ }
    alb_load_balancers = { /* ALB details */ }
    cloudfront_distributions = { /* CloudFront details with ALB origins */ }
    waf_web_acls = { /* WAF details with protected resources */ }
  }
}
```

## Best Practices

1. **Naming Convention**: Use consistent naming across modules (e.g., linux-*, windows-*)
2. **Environment Isolation**: Use separate configurations per environment
3. **Security**: Progressively stricter security from dev to prod
4. **Monitoring**: Enable logging and metrics at each layer
5. **Tags**: Consistent tagging for resource management and cost allocation

## Troubleshooting

### Common Issues
1. **ALB DNS not found**: Ensure ALB module key matches `alb_origin` in CloudFront spec
2. **CloudFront ARN not found**: Ensure CloudFront module key matches `protected_distributions` in WAF spec
3. **Circular dependencies**: Follow the deployment order (EC2/ALB → CloudFront → WAF)

### Validation Commands
```bash
# Check ALB DNS names
terraform output alb_endpoints

# Check CloudFront distributions
terraform output cloudfront_endpoints

# Check complete architecture flow
terraform output architecture_flow
```