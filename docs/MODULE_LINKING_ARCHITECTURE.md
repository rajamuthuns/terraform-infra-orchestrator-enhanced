# Module Linking Architecture

Detailed guide on how modules interconnect and reference each other in the orchestrator.

## Module Dependency Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│     EC2     │───▶│     ALB     │───▶│ CloudFront  │───▶│     WAF     │
│ Instances   │    │Load Balancer│    │Distribution │    │Web ACL      │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## How Module Linking Works

### 1. Reference Variables
Modules reference each other using key names from tfvars specifications:

```hcl
# EC2 references ALB by name
ec2_spec = {
  "web-server" = {
    enable_alb_integration = true
    alb_name = "linux-alb"        # References alb_spec key
  }
}

# CloudFront references ALB by name
cloudfront_spec = {
  "web-cf" = {
    alb_origin = "linux-alb"      # References alb_spec key
  }
}
```

### 2. Automatic Resolution
The orchestrator automatically resolves these references:

```hcl
# In main.tf - EC2 Module
module "ec2_instance" {
  # Orchestrator resolves alb_name to actual target group ARN
  alb_target_group_arns = try(each.value.enable_alb_integration, false) ? 
    [module.alb[each.value.alb_name].default_target_group_arn] : []
}

# In main.tf - CloudFront Module  
module "cloudfront" {
  # Orchestrator resolves alb_origin to actual DNS name
  origin_domain_name = module.alb[each.value.alb_origin].alb_dns_name
}
```

### 3. Module Integration Points

#### EC2 → ALB Integration
- **Purpose**: Application servers connect to load balancer
- **Integration**: `alb_target_group_arns` from ALB module output
- **Configuration**: `enable_alb_integration = true` + `alb_name`

#### ALB → CloudFront Integration  
- **Purpose**: Load balancer serves as CloudFront origin
- **Integration**: `alb_dns_name` from ALB module output
- **Configuration**: `alb_origin` references ALB module key

#### CloudFront → WAF Integration
- **Purpose**: WAF protects CloudFront distributions
- **Integration**: `distribution_arn` from CloudFront module output
- **Configuration**: `waf_key` references WAF module key

#### WAF → CloudFront Integration
- **Purpose**: WAF associates with CloudFront distributions
- **Integration**: `associated_resource_arns` from CloudFront ARNs
- **Configuration**: `protected_distributions` list of CloudFront keys

## Complete Configuration Example

### Step 1: Define Base Resources
```hcl
# ALB Configuration
alb_spec = {
  "linux-alb" = {
    name = "linux-alb"
    vpc_name = "dev-vpc"
    http_enabled = true
    https_enabled = false
  }
}

# WAF Configuration
waf_spec = {
  "cloudfront-waf" = {
    scope = "CLOUDFRONT"
    enabled_aws_managed_rules = [
      "common_rule_set",
      "sqli_rule_set",
      "bot_control"
    ]
  }
}
```

### Step 2: Reference Base Resources
```hcl
# EC2 references ALB
ec2_spec = {
  "web-server" = {
    enable_alb_integration = true
    alb_name = "linux-alb"          # References alb_spec["linux-alb"]
    instance_type = "t3.micro"
    vpc_name = "dev-vpc"
  }
}

# CloudFront references ALB and WAF
cloudfront_spec = {
  "web-cf" = {
    distribution_name = "web-app-distribution"
    alb_origin = "linux-alb"        # References alb_spec["linux-alb"]
    waf_key = "cloudfront-waf"      # References waf_spec["cloudfront-waf"]
    price_class = "PriceClass_100"
  }
}
```

## Advanced Linking Patterns

### Multi-Environment References
```hcl
# Development - Single server
ec2_spec = {
  "web-server" = {
    alb_name = "linux-alb"
    instance_type = "t3.micro"
  }
}

# Production - Multiple servers
ec2_spec = {
  "web-server-1" = {
    alb_name = "linux-alb"          # Same ALB
    instance_type = "t3.medium"
  },
  "web-server-2" = {
    alb_name = "linux-alb"          # Same ALB
    instance_type = "t3.medium"
  }
}
```

### Cross-Module Dependencies
```hcl
# WAF protects multiple CloudFront distributions
waf_spec = {
  "multi-cf-waf" = {
    scope = "CLOUDFRONT"
    protected_distributions = ["linux-cf", "windows-cf"]  # Multiple references
  }
}

# Multiple CloudFront distributions using same ALB
cloudfront_spec = {
  "linux-cf" = {
    alb_origin = "linux-alb"
    waf_key = "multi-cf-waf"
  },
  "windows-cf" = {
    alb_origin = "windows-alb"
    waf_key = "multi-cf-waf"        # Same WAF
  }
}
```

## Dependency Resolution Order

```
1. ALB and WAF (Independent)
    ↓
2. EC2 Instances (depends on ALB target groups)
    ↓
3. CloudFront (depends on ALB DNS name)
    ↓
4. WAF Association (depends on CloudFront ARNs)
```

### Terraform Dependency Graph
```hcl
# Terraform automatically handles these dependencies:
module.alb["linux-alb"] → module.ec2_instance["web-server"]
module.alb["linux-alb"] → module.cloudfront["web-cf"]
module.waf["cloudfront-waf"] → module.cloudfront["web-cf"]
module.cloudfront["web-cf"] → module.waf["cloudfront-waf"] (association)
```

## Reference Resolution Examples

### EC2 → ALB Integration
```hcl
# Configuration
ec2_spec = {
  "web-server" = {
    enable_alb_integration = true
    alb_name = "linux-alb"          # Key reference
  }
}

# Orchestrator Resolution
module "ec2_instance" {
  alb_target_group_arns = try(each.value.enable_alb_integration, false) ? 
    [module.alb[each.value.alb_name].default_target_group_arn] : []
    # Resolves to: module.alb["linux-alb"].default_target_group_arn
}
```

### ALB → CloudFront Integration
```hcl
# Configuration
cloudfront_spec = {
  "web-cf" = {
    alb_origin = "linux-alb"        # Key reference
  }
}

# Orchestrator Resolution
module "cloudfront" {
  origin_domain_name = module.alb[each.value.alb_origin].alb_dns_name
  # Resolves to: module.alb["linux-alb"].alb_dns_name
}
```

### WAF → CloudFront Integration
```hcl
# Configuration
waf_spec = {
  "cloudfront-waf" = {
    protected_distributions = ["linux-cf", "windows-cf"]  # Key references
  }
}

# Orchestrator Resolution
module "waf" {
  associated_resource_arns = [
    for dist in each.value.protected_distributions :
    module.cloudfront[dist].distribution_arn
  ]
  # Resolves to: [
  #   module.cloudfront["linux-cf"].distribution_arn,
  #   module.cloudfront["windows-cf"].distribution_arn
  # ]
}
```

## Deployment Considerations

### Parallel Deployment
```hcl
# These can deploy simultaneously:
- module.alb (independent)
- module.waf (independent, creates WAF rules)

# These depend on ALB:
- module.ec2_instance (needs target group ARN)
- module.cloudfront (needs ALB DNS name)

# This depends on CloudFront:
- WAF association (needs distribution ARN)
```

### Terraform Apply Order
Terraform automatically determines the correct order based on dependencies:
1. ALB and WAF resources created first
2. EC2 instances and CloudFront distributions created next
3. WAF associations created last

## Validation and Outputs

### Checking Module Links
```bash
# Verify ALB endpoints
terraform output alb_endpoints

# Verify CloudFront distributions
terraform output cloudfront_endpoints

# Check complete architecture flow
terraform output architecture_flow
```

### Output Structure
```hcl
output "architecture_flow" {
  value = {
    ec2_instances = {
      for k, v in module.ec2_instance : k => {
        instance_id = v.instance_id
        alb_integration = v.alb_target_group_arns
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
        origin_alb = v.origin_domain_name
      }
    }
  }
}
```

## Best Practices for Module Linking

### Naming Conventions
```hcl
# Use descriptive, consistent names
alb_spec = {
  "web-alb" = { ... }      # Not "alb1"
  "api-alb" = { ... }      # Not "alb2"
}

ec2_spec = {
  "web-server-1" = { alb_name = "web-alb" }
  "api-server-1" = { alb_name = "api-alb" }
}
```

### Reference Validation
```hcl
# Always validate references exist
ec2_spec = {
  "web-server" = {
    alb_name = "web-alb"    # Ensure this key exists in alb_spec
  }
}
```

### Environment Consistency
```hcl
# Keep same reference structure across environments
# dev-terraform.tfvars
ec2_spec = {
  "web-server" = { alb_name = "web-alb" }
}

# prod-terraform.tfvars  
ec2_spec = {
  "web-server-1" = { alb_name = "web-alb" }  # Same reference pattern
  "web-server-2" = { alb_name = "web-alb" }
}
```

## Troubleshooting Module Links

### Common Reference Errors

#### 1. Key Not Found
```
Error: Invalid index
│ The given key does not correspond to an element in this collection.
```
**Solution**: Verify the reference key exists in the target specification
```hcl
# Check that "web-alb" exists in alb_spec
ec2_spec = {
  "web-server" = {
    alb_name = "web-alb"  # Must match alb_spec key
  }
}
```

#### 2. Circular Dependencies
```
Error: Cycle: module.cloudfront, module.waf
```
**Solution**: Check for circular references in configurations

#### 3. Missing Integration Flag
```
Error: ALB target group ARN is empty
```
**Solution**: Enable integration flag
```hcl
ec2_spec = {
  "web-server" = {
    enable_alb_integration = true  # Required for ALB linking
    alb_name = "web-alb"
  }
}
```

### Debugging Commands
```bash
# Check module state
terraform state list | grep module

# Verify specific module outputs
terraform state show 'module.alb["web-alb"]'

# Check dependency graph
terraform graph | dot -Tpng > graph.png
```

### Validation Checklist
```bash
# 1. Validate configuration syntax
terraform validate

# 2. Check planned dependencies
terraform plan -var-file=tfvars/dev-terraform.tfvars

# 3. Verify module outputs after apply
terraform output alb_endpoints
terraform output cloudfront_endpoints
terraform output architecture_flow

# 4. Test actual connectivity
curl -I $(terraform output -raw linux_alb_endpoint)
curl -I $(terraform output -raw linux_cloudfront_endpoint)
```