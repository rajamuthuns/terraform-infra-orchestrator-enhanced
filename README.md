# Terraform Infrastructure Orchestrator

A **production-ready Terraform orchestrator** that bridges and interlinks multiple base modules to deploy secure, scalable web infrastructure across **multiple AWS accounts** and **environments** with **seamless configuration management**.

## 🎯 What is This Orchestrator?

This orchestrator serves as a **configuration bridge** that:
- **Downloads and integrates** base modules from Terraform Registry and GitHub
- **Manages inter-module dependencies** automatically across environments
- **Provides seamless multi-account deployments** with consistent patterns
- **Handles module versioning** and compatibility across workspaces
- **Simplifies complex configurations** through unified tfvars files
- **Enforces security best practices** with CloudFront WAF and managed prefix lists

## 🏗️ Orchestrator Architecture

**Module Integration Flow:**
```
tfvars/*.tfvars → main.tf (Orchestrator) → Base Modules → AWS Resources
       ↑                    ↑                    ↑              ↑
Configuration        Module Bridge        Registry/GitHub    Infrastructure
   Files            & Dependency         Module Sources      Deployment
                     Management
```

**Base Modules Integrated:**
- **ALB Module**: `git::https://github.com/Norfolk-Southern/ns-itcp-tf-mod-alb.git` - Load balancer with health checks
- **EC2 Module**: `git::https://github.com/rajamuthuns/ec2-base-module.git` - Instances with auto-configuration
- **WAF Module**: `git::https://github.com/rajamuthuns/tf-waf-base-module.git` - Web Application Firewall with comprehensive rules
- **CloudFront Module**: `git::https://github.com/rajamuthuns/tf-cf-base-module.git` - CDN with WAF protection

## 🔗 Module Interlinking & Configuration Bridge

### Automatic Module Linking
```hcl
# CloudFront automatically links to ALB and WAF
cloudfront_spec = {
  linux-cf = {
    alb_origin = "linux-alb"        # → Links to module.alb["linux-alb"]
    waf_key    = "cloudfront-waf"   # → Links to module.waf["cloudfront-waf"]
  }
}

# EC2 automatically integrates with ALB target groups
ec2_spec = {
  "linux-webserver" = {
    enable_alb_integration = true
    alb_name = "linux-alb"          # → Links to module.alb["linux-alb"].target_group_arn
  }
}
```

### Configuration Simplification
**Before (Complex Module Configuration):**
```hcl
# Multiple module calls with complex dependencies
module "alb" { ... }
module "ec2" { 
  target_group_arns = [module.alb.target_group_arn]
}
module "cloudfront" {
  origin_domain_name = module.alb.dns_name
  web_acl_id = module.waf.web_acl_arn
}
```

**After (Orchestrator Simplification):**
```hcl
# Single tfvars configuration - orchestrator handles linking
alb_spec = { linux-alb = { ... } }
ec2_spec = { "webserver" = { alb_name = "linux-alb" } }
cloudfront_spec = { "web-cf" = { alb_origin = "linux-alb" } }
```

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Access to target AWS accounts
- **Security Group Quota Increase** (see [detailed guide](docs/SECURITY_GROUP_QUOTA_INCREASE.md))

### Deploy Infrastructure
```bash
# Initialize with shared backend
terraform init -backend-config=shared/backend-common.hcl

# Select environment workspace
terraform workspace select dev || terraform workspace new dev

# Deploy with environment-specific configuration
terraform apply -var-file=tfvars/dev-terraform.tfvars
```

### Validate Deployment
```bash
# Test infrastructure and security
./scripts/test_cloudfront_security.sh

# Get orchestrated infrastructure outputs
terraform output
```

## 📁 Orchestrator Structure

```
tf-enhanced/                        # Orchestrator Root
├── main.tf                         # 🎯 Main orchestrator (module bridge)
├── variables.tf                    # Variable definitions for all modules
├── outputs.tf                      # Unified outputs from all modules
├── backend.tf                      # Shared backend configuration
├── tfvars/                         # 🔧 Environment-specific configurations
│   ├── dev-terraform.tfvars        # Development environment config
│   ├── stg-terraform.tfvars        # Staging environment config
│   └── prod-terraform.tfvars       # Production environment config
├── scripts/                        # 🛡️ Validation and testing scripts
│   └── test_cloudfront_security.sh # Security testing script
├── userdata/                       # Server initialization scripts
├── shared/                         # Shared backend configuration
└── docs/                           # Detailed documentation
    └── ARCHITECTURE.md             # Detailed technical architecture
```

## 🌍 Multi-Environment & Multi-Account Orchestration

### Environment Configuration Matrix
| Environment | Account | Modules Used | Instance Types | Storage | Monitoring |
|-------------|---------|-------------|---------------|---------|------------|
| **Development** | Dev Account | ALB+EC2+WAF+CF | t3.small/medium | 20-100GB | Basic |
| **Staging** | Staging Account | ALB+EC2+WAF+CF | t3.medium/large | 30-300GB | Enhanced |
| **Production** | Prod Account | ALB+EC2+WAF+CF | t3.large+ | 50-500GB+ | Full SOC |

### Cross-Account Deployment Workflow
```
Dev Account    → terraform workspace select dev    → tfvars/dev-terraform.tfvars
Staging Account → terraform workspace select staging → tfvars/stg-terraform.tfvars  
Prod Account   → terraform workspace select production → tfvars/prod-terraform.tfvars
```

## 🔧 Configuration Management

### Adding New Infrastructure Components
```hcl
# tfvars/dev-terraform.tfvars - Single configuration file
ec2_spec = {
  "new-webserver" = {
    enable_alb_integration = true      # Orchestrator handles ALB linking
    alb_name               = "linux-alb"
    instance_type          = "t3.small"
    vpc_name               = "dev-mig-target-vpc"
    ami_name               = "amzn2-ami-hvm-*-x86_64-gp2"
    os_type                = "linux"
    subnet_name            = "dev-mig-private-subnet-1"
    
    ingress_rules = [
      {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "SSH access from private networks"
      },
      {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "HTTP access from ALB"
      }
    ]
  }
}
```

## 🚀 Orchestrator Commands

### Multi-Environment Deployment
```bash
# Development Environment
terraform workspace select dev
terraform apply -var-file=tfvars/dev-terraform.tfvars

# Staging Environment  
terraform workspace select staging
terraform apply -var-file=tfvars/stg-terraform.tfvars

# Production Environment
terraform workspace select production
terraform apply -var-file=tfvars/prod-terraform.tfvars
```

### Orchestrator Validation
```bash
# Check orchestrated infrastructure
terraform show

# View all module outputs
terraform output

# Validate module interlinking
terraform output architecture_flow

# Test security and functionality
./scripts/test_cloudfront_security.sh
```

## 🔗 Module Integration Benefits

### Before Orchestrator (Manual Module Management)
- ❌ Complex module dependencies across environments
- ❌ Repetitive configuration for each account/environment
- ❌ Manual output/input linking between modules
- ❌ Inconsistent naming and tagging across deployments
- ❌ Difficult environment and account promotion
- ❌ Module version conflicts between environments

### After Orchestrator (Automated Integration)
- ✅ **Simplified Configuration**: Single tfvars file per environment
- ✅ **Automatic Linking**: Modules reference each other automatically
- ✅ **Consistent Patterns**: Standardized naming and tagging across accounts
- ✅ **Environment Parity**: Same configuration structure across all environments
- ✅ **Easy Scaling**: Add resources with minimal configuration
- ✅ **Cross-Account Support**: Seamless deployment across AWS accounts
- ✅ **Version Management**: Consistent module versions across environments

## 🛡️ Security Architecture

### CloudFront Security Integration
```hcl
# Orchestrator automatically configures security
waf_spec = {
  cloudfront-waf = {
    scope = "CLOUDFRONT"
    enabled_aws_managed_rules = [
      "common_rule_set", "sqli_rule_set", "bot_control"
    ]
  }
}

# ALB Security Groups use AWS managed CloudFront prefix lists
alb_spec = {
  linux-alb = {
    http_ingress_prefix_list_ids = ["pl-3b927c52"]  # AWS managed
  }
}
```

**Security Benefits:**
- ✅ **AWS Managed Prefix Lists**: CloudFront IPs automatically updated
- ✅ **Attack Protection**: OWASP Top 10, bot control, rate limiting
- ✅ **Global Edge Security**: Protection at 400+ CloudFront locations
- ✅ **Zero Direct Access**: ALB only accessible via CloudFront

## 📚 Documentation

For detailed technical information, see:
- **[Security Group Quota Increase Guide](docs/SECURITY_GROUP_QUOTA_INCREASE.md)** - ⚠️ **REQUIRED**: Step-by-step quota increase process
- **[Architecture Guide](docs/architecture.md)** - Detailed technical architecture and component details
- **[Module Linking Architecture](docs/module_linking_architecture.md)** - How modules interconnect and dependency management
- **[GitHub Actions Setup](docs/github_actions_setup.md)** - CI/CD pipeline configuration and GitOps workflow
- **[Infrastructure Setup](docs/infra_setup.md)** - Initial infrastructure setup and prerequisites
- **[Shared Services Backend Setup](docs/shared_services_backend_setup.md)** - Backend configuration and state management
- **[Troubleshooting Guide](docs/troubleshooting.md)** - Common issues, solutions, and diagnostic commands
- **[GitFlow Diagram](docs/GitFlow.jpg)** - Visual representation of the GitOps workflow

## 🎯 Current Orchestrated Infrastructure

**✅ Successfully Orchestrated:**
- **4 Base Modules** integrated and interlinked across environments
- **Multi-environment support** (dev/staging/prod) with workspace management
- **Cross-account deployment** capability with consistent configuration
- **Automatic dependency management** between modules
- **Unified configuration** through environment-specific tfvars files
- **Consistent resource naming** and tagging across all deployments
- **Security integration** with CloudFront WAF and managed prefix lists

**🔧 Orchestrator Features:**
- **Module Version Management**: Consistent module versions across environments
- **Configuration Validation**: Built-in validation for module compatibility
- **Dependency Resolution**: Automatic handling of module interdependencies
- **Environment Promotion**: Easy configuration promotion between environments
- **Cross-Account Support**: Seamless deployment across multiple AWS accounts
- **Workspace Management**: Terraform workspace integration for environment isolation
- **Security Integration**: Built-in security best practices and validation

**🌐 Multi-Account Architecture:**
- **Account Isolation**: Separate AWS accounts for dev/staging/production
- **Consistent Configuration**: Same orchestrator patterns across all accounts
- **Cross-Account Backend**: Shared Terraform state management
- **Environment Parity**: Identical infrastructure patterns with environment-specific sizing
- **Security Compliance**: Consistent security policies across all accounts

---

**Ready to orchestrate your infrastructure?** This orchestrator simplifies complex multi-module deployments across multiple AWS accounts and environments into manageable, consistent configurations! 🚀