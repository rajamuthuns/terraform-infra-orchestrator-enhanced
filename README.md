# Terraform Infrastructure Orchestrator

A **production-ready Terraform orchestrator** that bridges and interlinks multiple base modules from the Terraform Registry to deploy secure, scalable web infrastructure across multiple environments with simplified configuration management.

## 🎯 What is This Orchestrator?

This orchestrator serves as a **configuration bridge** that:
- **Downloads and integrates** base modules from Terraform Registry and GitHub
- **Simplifies complex configurations** through unified tfvars files
- **Manages inter-module dependencies** automatically
- **Provides environment-specific deployments** with consistent patterns
- **Handles module versioning** and compatibility

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
- **ALB Module**: `git::https://github.com/YOUR_ORG_NAME/tf-alb-main.git` - Application Load Balancer with health checks
- **EC2 Module**: `git::https://github.com/YOUR_ORG_NAME/ec2-base-module.git` - EC2 instances with auto-configuration
- **WAF Module**: `git::https://github.com/YOUR_ORG_NAME/tf-waf-base-module.git` - Web Application Firewall with comprehensive rules
- **CloudFront Module**: `git::https://github.com/YOUR_ORG_NAME/tf-cf-base-module.git` - CDN with PING authentication

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

### Deploy Infrastructure
```bash
# Initialize with shared backend
terraform init -backend-config=shared/backend-common.hcl

# Select environment workspace
terraform workspace select dev || terraform workspace new dev

# Deploy with environment-specific configuration
terraform apply -var-file=tfvars/dev-terraform.tfvars
```

### Access Your Applications
```bash
# Get orchestrated infrastructure outputs
terraform output architecture_flow

# Access CloudFront URLs (orchestrator-managed)
terraform output cloudfront_endpoints
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
├── modules/                        # 📦 Downloaded GitHub modules (auto-managed)
│   ├── tf-alb-main/               # ALB module from GitHub
│   ├── tf-cf-base-module/         # CloudFront module from GitHub
│   └── tf-waf-base-module/        # WAF module from GitHub
├── userdata/                       # Server initialization scripts
├── scripts/                        # Validation and testing scripts
├── shared/                         # Shared backend configuration
└── docs/                           # Detailed documentation
    └── ARCHITECTURE.md             # Detailed technical architecture
```

## 🌍 Multi-Environment Orchestration

### Environment Configuration Matrix
| Environment | Modules Used | Instance Types | WAF Rules | Storage | Retention |
|-------------|-------------|---------------|-----------|---------|-----------|
| **Development** | ALB+EC2+WAF+CF | t3.small/medium | 7 AWS + 2 Custom | 20-100GB | 180 days |
| **Staging** | ALB+EC2+WAF+CF | t3.medium/large | 7 AWS + 2 Custom | 30-300GB | 90 days |
| **Production** | ALB+EC2+WAF+CF | t3.large+ | 8 AWS + 2 Custom | 50-500GB+ | 365 days |

### GitOps Orchestration Workflow
```
Feature Branch → Dev Environment    → tfvars/dev-terraform.tfvars
Staging Branch → Staging Environment → tfvars/stg-terraform.tfvars  
Main Branch    → Production Environment → tfvars/prod-terraform.tfvars
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

### Environment Deployment
```bash
# Development
terraform workspace select dev
terraform apply -var-file=tfvars/dev-terraform.tfvars

# Staging  
terraform workspace select staging
terraform apply -var-file=tfvars/stg-terraform.tfvars

# Production
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
```

## 🔗 Module Integration Benefits

### Before Orchestrator (Manual Module Management)
- ❌ Complex module dependencies
- ❌ Repetitive configuration across environments
- ❌ Manual output/input linking between modules
- ❌ Inconsistent naming and tagging
- ❌ Difficult environment promotion

### After Orchestrator (Automated Integration)
- ✅ **Simplified Configuration**: Single tfvars file per environment
- ✅ **Automatic Linking**: Modules reference each other automatically
- ✅ **Consistent Patterns**: Standardized naming and tagging
- ✅ **Environment Parity**: Same configuration structure across environments
- ✅ **Easy Scaling**: Add resources with minimal configuration

## 📚 Documentation

For detailed technical information, see:
- **[Architecture Guide](docs/architecture.md)** - Detailed technical architecture and component details
- **[Module Linking Architecture](docs/module_linking_architecture.md)** - How modules interconnect and dependency management
- **[GitHub Actions Setup](docs/github_actions_setup.md)** - CI/CD pipeline configuration and GitOps workflow
- **[Infrastructure Setup](docs/infra_setup.md)** - Initial infrastructure setup and prerequisites
- **[Shared Services Backend Setup](docs/shared_services_backend_setup.md)** - Backend configuration and state management
- **[Troubleshooting Guide](docs/troubleshooting.md)** - Common issues, solutions, and diagnostic commands
- **[GitFlow Diagram](docs/GitFlow.jpg)** - Visual representation of the GitOps workflow

## 🎯 Current Orchestrated Infrastructure

**✅ Successfully Orchestrated:**
- **4 Base Modules** integrated and interlinked
- **Multi-environment support** (dev/staging/prod)
- **Automatic dependency management** between modules
- **Unified configuration** through tfvars files
- **Consistent resource naming** and tagging

**🔧 Orchestrator Features:**
- **Module Version Management**: Consistent module versions across environments
- **Configuration Validation**: Built-in validation for module compatibility
- **Dependency Resolution**: Automatic handling of module interdependencies
- **Environment Promotion**: Easy configuration promotion between environments

---

**Ready to orchestrate your infrastructure?** This orchestrator simplifies complex multi-module deployments into manageable, environment-specific configurations! 🚀