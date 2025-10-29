# Terraform Infrastructure Orchestrator - Architecture Guide

This document provides detailed technical architecture information for the **Terraform Infrastructure Orchestrator** and its multi-module integration capabilities.

## 🎯 Orchestrator Overview

The Terraform Infrastructure Orchestrator serves as a **configuration bridge** that automatically manages dependencies between multiple base modules, enabling seamless deployment across multiple AWS accounts and environments.

### Core Orchestrator Principles
- **Module Abstraction**: Hide complex module interdependencies
- **Configuration Unification**: Single tfvars file per environment
- **Cross-Account Consistency**: Same patterns across all AWS accounts
- **Environment Parity**: Identical structure with environment-specific sizing
- **Automatic Linking**: Modules reference each other through orchestrator logic

## 🏗️ Multi-Module Architecture

### Orchestrator Integration Flow
```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Terraform Infrastructure Orchestrator                │
├─────────────────────────────────────────────────────────────────────────┤
│  tfvars/dev.tfvars → main.tf (Bridge) → GitHub Modules → AWS Resources  │
│       ↑                   ↑                   ↑              ↑          │
│  Environment        Module Bridge      Base Modules    Infrastructure    │
│  Configuration    & Dependency Mgmt   (GitHub Sources)   Deployment     │
└─────────────────────────────────────────────────────────────────────────┘
```

### Base Module Integration
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ALB Module    │    │   EC2 Module    │    │   WAF Module    │
│ (Load Balancer) │◄──►│  (Instances)    │    │ (Security)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       ▲                       ▲
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 ▼
                    ┌─────────────────┐
                    │ CloudFront Mod  │
                    │ (CDN + WAF)     │
                    └─────────────────┘
```

## 🔗 Module Interlinking Architecture

### Automatic Dependency Resolution
The orchestrator automatically resolves and manages dependencies between modules:

```hcl
# Orchestrator automatically creates these links:
module "ec2_instance" {
  # ALB Integration - Orchestrator handles target group ARN linking
  alb_target_group_arns = try(each.value.enable_alb_integration, false) ? 
    [module.alb[each.value.alb_name].default_target_group_arn] : []
}

module "cloudfront" {
  # ALB Integration - Orchestrator handles DNS name linking
  origin_domain_name = module.alb[each.value.alb_origin].alb_dns_name
  
  # WAF Integration - Orchestrator handles WAF ARN linking
  web_acl_id = try(each.value.waf_key, null) != null ? 
    module.waf[each.value.waf_key].web_acl_arn : null
}
```

### Configuration Abstraction Layer
```
┌─────────────────────────────────────────────────────────────────┐
│                    Configuration Layer                          │
├─────────────────────────────────────────────────────────────────┤
│  alb_spec = { linux-alb = { ... } }                           │
│  ec2_spec = { webserver = { alb_name = "linux-alb" } }        │
│  cloudfront_spec = { web-cf = { alb_origin = "linux-alb" } }  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Orchestrator Logic                           │
├─────────────────────────────────────────────────────────────────┤
│  • Resolves module dependencies automatically                  │
│  • Links outputs to inputs across modules                      │
│  • Manages resource naming and tagging                         │
│  • Handles environment-specific configurations                 │
└─────────────────────────────────────────────────────────────────┘
```

## 🌍 Multi-Account & Multi-Environment Architecture

### Cross-Account Deployment Pattern
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Dev Account    │    │ Staging Account │    │  Prod Account   │
│  (221106935066) │    │  (137617557860) │    │  (221106935066) │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • t3.small      │    │ • t3.medium     │    │ • t3.large+     │
│ • 20-100GB      │    │ • 30-300GB      │    │ • 50-500GB+     │
│ • Basic Monitor │    │ • Enhanced Mon  │    │ • Full SOC      │
│ • 9 WAF Rules   │    │ • 7 WAF Rules   │    │ • 10 WAF Rules  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ dev-terraform   │    │ stg-terraform   │    │prod-terraform   │
│ .tfvars         │    │ .tfvars         │    │ .tfvars         │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Workspace Management Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                    Terraform Workspaces                        │
├─────────────────────────────────────────────────────────────────┤
│  terraform workspace select dev      → tfvars/dev-terraform.tfvars  │
│  terraform workspace select staging  → tfvars/stg-terraform.tfvars  │
│  terraform workspace select production → tfvars/prod-terraform.tfvars │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                 State Isolation                                 │
├─────────────────────────────────────────────────────────────────┤
│  • Separate state files per environment                        │
│  • Cross-account provider configuration                        │
│  • Environment-specific resource naming                        │
│  • Isolated infrastructure per workspace                       │
└─────────────────────────────────────────────────────────────────┘
```

## 🛡️ Security Architecture Integration

### CloudFront Security Flow
```
┌─────────────────────────────────────────────────────────────────┐
│                    Security Architecture                        │
├─────────────────────────────────────────────────────────────────┤
│  Browser → CloudFront → CloudFront WAF → ALB → EC2             │
│     ↑          ↑            ↑              ↑      ↑            │
│   User    Edge Cache   Attack Filter   Prefix    Apps          │
│  Traffic   + SSL/TLS   (OWASP/Bot)     List     Serve          │
└─────────────────────────────────────────────────────────────────┘
```

### Security Group Quota Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                Security Group Quota Management                  │
├─────────────────────────────────────────────────────────────────┤
│  Default Quota: 60 rules per security group                    │
│  Required Quota: 500 rules per security group                  │
│  CloudFront Prefix List: ~300 IP ranges (pl-3b927c52)         │
│  Buffer: 200 rules for future CloudFront expansion             │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Module Configuration Architecture

### Base Module Sources
```hcl
# ALB Module - Load Balancer with Health Checks
module "alb" {
  source = "git::https://github.com/Norfolk-Southern/ns-itcp-tf-mod-alb.git?ref=main"
  # Orchestrator manages: VPC discovery, subnet selection, security groups
}

# EC2 Module - Instances with Auto-Configuration  
module "ec2_instance" {
  source = "git::https://github.com/rajamuthuns/ec2-base-module.git?ref=main"
  # Orchestrator manages: ALB integration, target group linking, userdata
}

# WAF Module - Web Application Firewall
module "waf" {
  source = "git::https://github.com/rajamuthuns/tf-waf-base-module.git?ref=main"
  # Orchestrator manages: CloudFront association, rule configuration
}

# CloudFront Module - CDN with WAF Protection
module "cloudfront" {
  source = "git::https://github.com/rajamuthuns/tf-cf-base-module.git?ref=main"
  # Orchestrator manages: ALB origin linking, WAF association
}
```

### Configuration Inheritance Pattern
```
┌─────────────────────────────────────────────────────────────────┐
│                Environment Configuration Inheritance             │
├─────────────────────────────────────────────────────────────────┤
│  Base Configuration (All Environments)                         │
│  ├── Module sources and versions                               │
│  ├── Security group patterns                                   │
│  ├── Naming conventions                                        │
│  └── Tagging standards                                         │
│                                                                │
│  Environment Overrides                                         │
│  ├── dev-terraform.tfvars    → Development sizing             │
│  ├── stg-terraform.tfvars    → Staging validation             │
│  └── prod-terraform.tfvars   → Production scale               │
└─────────────────────────────────────────────────────────────────┘
```

## 🔄 Data Flow Architecture

### Request Flow Through Orchestrated Infrastructure
```
1. User Request → CloudFront Edge Location
2. CloudFront → CloudFront WAF (Attack Protection)
3. CloudFront → ALB (via AWS managed prefix list)
4. ALB → Health Check Validation
5. ALB → Target EC2 Instance (Private Subnet)
6. EC2 → Process Request (Apache/IIS)
7. EC2 → Return Response via ALB
8. ALB → CloudFront → User
```

### Module Communication Flow
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CloudFront    │    │      ALB        │    │      EC2        │
│                 │    │                 │    │                 │
│ • Domain Name   │───►│ • DNS Name      │───►│ • Target Group  │
│ • WAF ARN       │    │ • Target Group  │    │ • Health Check  │
│ • SSL Cert      │    │ • Health Check  │    │ • Auto Scaling  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       ▲                       ▲
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │      WAF        │
                    │                 │
                    │ • Web ACL ARN   │
                    │ • Rule Sets     │
                    │ • IP Sets       │
                    └─────────────────┘
```

## 📊 Monitoring & Observability Architecture

### Built-in Orchestrator Monitoring
```hcl
# Automatic health endpoints on all instances
health_endpoints = {
  linux   = "/health"      # Apache health check
  windows = "/health.txt"  # IIS health check
}

# ALB health check configuration
health_check = {
  path     = "/health"
  matcher  = "200"
  interval = 30
  timeout  = 5
}
```

### Multi-Environment Monitoring Matrix
| Environment | Monitoring Level | Health Checks | Logging | Alerting |
|-------------|------------------|---------------|---------|----------|
| Development | Basic | ALB Health | Local Logs | Manual |
| Staging | Enhanced | ALB + Custom | CloudWatch | Basic |
| Production | Full SOC | Comprehensive | Full Logging | Advanced |

## 🚀 Deployment Architecture

### Orchestrator Deployment Flow
```
1. Environment Selection
   └── terraform workspace select {env}

2. Configuration Loading  
   └── terraform apply -var-file=tfvars/{env}-terraform.tfvars

3. Module Resolution
   └── Download and cache GitHub modules

4. Dependency Planning
   └── Calculate inter-module dependencies

5. Resource Creation
   └── Deploy modules in dependency order

6. Validation
   └── ./scripts/test_cloudfront_security.sh
```

### GitOps Integration Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                    GitOps Workflow                             │
├─────────────────────────────────────────────────────────────────┤
│  Feature Branch → Dev Environment → Validation                 │
│  Staging Branch → Staging Environment → Integration Testing    │
│  Main Branch → Production Environment → Production Deployment  │
└─────────────────────────────────────────────────────────────────┘
```

## 🔧 Orchestrator Benefits Architecture

### Configuration Complexity Reduction
```
┌─────────────────────────────────────────────────────────────────┐
│                    Before Orchestrator                         │
├─────────────────────────────────────────────────────────────────┤
│  • 4 separate module configurations per environment            │
│  • Manual dependency management                                │
│  • Complex output/input linking                                │
│  • Inconsistent naming across environments                     │
│  • Environment-specific module versions                        │
│  • Manual cross-account configuration                          │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    After Orchestrator                          │
├─────────────────────────────────────────────────────────────────┤
│  • Single tfvars file per environment                          │
│  • Automatic dependency resolution                             │
│  • Transparent module linking                                  │
│  • Consistent patterns across all accounts                     │
│  • Unified module version management                           │
│  • Seamless cross-account deployment                           │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 Orchestrator Success Metrics

### Infrastructure Consistency
- ✅ **4 Base Modules** integrated and interlinked
- ✅ **3 Environments** (dev/staging/prod) with consistent patterns
- ✅ **Multiple AWS Accounts** supported seamlessly
- ✅ **Automatic Dependency Management** between all modules
- ✅ **Unified Configuration** through environment-specific tfvars
- ✅ **Version Consistency** across all environments and accounts

### Operational Efficiency
- ✅ **Configuration Reduction**: 75% fewer configuration files
- ✅ **Deployment Time**: Consistent deployment patterns
- ✅ **Error Reduction**: Automatic dependency resolution
- ✅ **Environment Parity**: Identical patterns across accounts
- ✅ **Scaling Simplicity**: Add resources with minimal configuration

This orchestrator architecture provides a robust foundation for managing complex, multi-module infrastructure deployments across multiple AWS accounts and environments with maximum consistency and minimal operational overhead.