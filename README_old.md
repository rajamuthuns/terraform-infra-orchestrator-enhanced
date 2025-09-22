# Terraform Infrastructure Orchestrator

A **production-ready Terraform orchestrator** that acts as a wrapper around base infrastructure modules, enabling teams to build complex, multi-environment infrastructure using reusable components with minimal configuration.

## 🎯 What is This Repository?

This repository is an **Infrastructure Orchestrator** that:

- 🧩 **Wraps base modules** - Downloads and orchestrates multiple Terraform base modules
- 🏗️ **Simplifies infrastructure** - Provides high-level abstractions for complex deployments  
- 🌍 **Multi-environment ready** - Supports dev, staging, and production with workspace isolation
- 🔄 **Enables module linking** - Connects modules using reference variables and outputs
- 📦 **Batch deployments** - Deploy multiple resources in one call using `for_each`
- 🎛️ **Configuration-driven** - Define entire infrastructure through `terraform.tfvars`

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                 Terraform Orchestrator                      │
│                    (This Repository)                        │
├─────────────────────────────────────────────────────────────┤
│  environments/                                              │
│  ├── dev/main.tf      ← Orchestrates base modules          │
│  ├── staging/main.tf  ← Environment-specific configs       │
│  └── prod/main.tf     ← Production settings                │
└─────────────────────┬───────────────────────────────────────┘
                      │ Downloads & Uses
┌─────────────────────▼───────────────────────────────────────┐
│                 Base Modules                                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   EC2 Module    │  │   ALB Module    │  │  RDS Module  │ │
│  │ (External Repo) │  │ (External Repo) │  │(External Repo│ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### 1. Clone and Setup
```bash
git clone <repository-url>
cd terraform-infra-orchestrator
```

### 2. Configure Your Infrastructure
```bash
cd environments/dev
# Edit terraform.tfvars with your specifications
nano terraform.tfvars
```

### 3. Deploy
```bash
terraform init
terraform plan
terraform apply
```

## 📁 Repository Structure

```
terraform-infra-orchestrator/
├── README.md                          # This guide
├── environments/                      # Environment-specific configurations
│   ├── dev/                          # Development environment
│   │   ├── main.tf                   # Module orchestration logic
│   │   ├── variables.tf              # Variable definitions
│   │   ├── outputs.tf                # Output definitions
│   │   ├── terraform.tfvars          # Dev-specific values
│   │   ├── userdata-linux.sh         # Linux server initialization
│   │   └── userdata-windows.ps1      # Windows server initialization
│   ├── staging/                      # Staging environment
│   └── prod/                         # Production environment
├── scripts/                          # Utility scripts
├── docs/                             # Documentation
└── .github/workflows/                # CI/CD pipelines
```

## 🧩 How Base Module Integration Works

### **Module Download and Usage**
The orchestrator automatically downloads and uses base modules:

```hcl
# In main.tf
module "ec2_instance" {
  source = "../../../ec2-base-module"    # Local path to downloaded module
  # OR
  source = "git::https://github.com/org/ec2-base-module.git?ref=main"
  
  for_each = var.ec2_spec              # Deploy multiple instances
  
  # Pass configuration from terraform.tfvars
  name_prefix   = each.key
  instance_type = each.value.instance_type
  vpc_name      = each.value.vpc_name
  # ... other parameters
}
```

### **Configuration-Driven Deployment**
Define your entire infrastructure in `terraform.tfvars`:

```hcl
# terraform.tfvars
ec2_spec = {
  "web-server-1" = {
    instance_type = "t3.medium"
    vpc_name      = "my-vpc"
    ami_name      = "amzn2-ami-hvm-*"
    # ... other settings
  },
  "web-server-2" = {
    instance_type = "t3.large"
    vpc_name      = "my-vpc"
    ami_name      = "amzn2-ami-hvm-*"
    # ... other settings
  }
}
```

## 🔗 Module Linking and Reference Variables

### **Linking Modules Together**
Connect modules using reference variables and outputs:

```hcl
# ALB Module
module "alb" {
  source = "../../../tf-alb"
  for_each = var.alb_spec
  
  vpc_name = each.value.vpc_name
  name     = "${each.value.name}-${var.environment}"
}

# EC2 Module - References ALB output
module "ec2_instance" {
  source = "../../../ec2-base-module"
  for_each = var.ec2_spec
  
  # Link to ALB target group
  enable_alb_integration = try(each.value.enable_alb_integration, false)
  alb_target_group_arns  = try(each.value.enable_alb_integration, false) ? 
    [module.alb[each.value.alb_name].default_target_group_arn] : []
}
```

### **Cross-Module References in terraform.tfvars**
```hcl
# Define ALB first
alb_spec = {
  web-alb = {
    name = "web-alb"
    vpc_name = "my-vpc"
  }
}

# Reference ALB in EC2 configuration
ec2_spec = {
  "web-server" = {
    enable_alb_integration = true
    alb_name = "web-alb"              # References the ALB above
    instance_type = "t3.medium"
  }
}
```

## 📦 Adding New Base Modules

### **Step 1: Add Module to main.tf**
```hcl
# Add new module block
module "rds_instance" {
  source = "../../../rds-base-module"
  for_each = var.rds_spec
  
  # Module-specific parameters
  db_name           = each.value.db_name
  engine            = each.value.engine
  instance_class    = each.value.instance_class
  vpc_name          = each.value.vpc_name
  
  # Link to other modules if needed
  vpc_security_group_ids = [module.ec2_instance[each.value.ec2_ref].security_group_id]
}
```

### **Step 2: Add Variable Definition**
```hcl
# In variables.tf
variable "rds_spec" {
  description = "RDS instance specifications"
  type        = any
  default     = {}
}
```

### **Step 3: Add Output**
```hcl
# In outputs.tf
output "rds_details" {
  description = "RDS instance details"
  value = {
    for k, v in module.rds_instance : k => {
      endpoint = v.db_endpoint
      port     = v.db_port
    }
  }
}
```

### **Step 4: Configure in terraform.tfvars**
```hcl
# In terraform.tfvars
rds_spec = {
  "app-database" = {
    db_name        = "appdb"
    engine         = "mysql"
    instance_class = "db.t3.micro"
    vpc_name       = "my-vpc"
    ec2_ref        = "web-server"    # Reference to EC2 for security group
  }
}
```

## 🌍 Multi-Environment Management

### **Environment Structure**
Each environment has its own directory with identical structure but different configurations:

```
environments/
├── dev/
│   ├── main.tf           # Same orchestration logic
│   └── terraform.tfvars  # Dev-specific values (small instances)
├── staging/
│   ├── main.tf           # Same orchestration logic  
│   └── terraform.tfvars  # Staging values (production-like)
└── prod/
    ├── main.tf           # Same orchestration logic
    └── terraform.tfvars  # Production values (large, secure)
```

### **Environment-Specific Naming**
Resources automatically get environment suffixes:

```hcl
# In main.tf
name = "${each.value.name}-${var.environment}"

# Results in:
# Dev: web-server-dev, database-dev
# Staging: web-server-staging, database-staging  
# Prod: web-server-prod, database-prod
```

### **Terraform Workspaces**
Each environment uses its own workspace:

```bash
# Development
cd environments/dev
terraform workspace select dev || terraform workspace new dev

# Staging  
cd environments/staging
terraform workspace select staging || terraform workspace new staging

# Production
cd environments/prod
terraform workspace select prod || terraform workspace new prod
```

## 🔄 Batch Deployments with for_each

### **Deploy Multiple Resources in One Call**
```hcl
# Deploy 5 web servers with one configuration
ec2_spec = {
  "web-server-1" = { instance_type = "t3.medium", az = "us-east-1a" },
  "web-server-2" = { instance_type = "t3.medium", az = "us-east-1b" },
  "web-server-3" = { instance_type = "t3.large",  az = "us-east-1c" },
  "app-server-1" = { instance_type = "t3.xlarge", az = "us-east-1a" },
  "app-server-2" = { instance_type = "t3.xlarge", az = "us-east-1b" }
}

# Deploy multiple ALBs
alb_spec = {
  web-alb = { name = "web-alb", type = "application" },
  api-alb = { name = "api-alb", type = "application" }
}
```

### **Conditional Resource Creation**
```hcl
# Only create resources based on conditions
ec2_spec = {
  "web-server" = {
    instance_type = "t3.medium"
    create_backup = true                    # Conditional feature
    enable_monitoring = var.environment == "prod" ? true : false
  }
}
```

## 🎛️ Advanced Configuration Patterns

### **Environment-Specific Sizing**
```hcl
# terraform.tfvars - automatically scales by environment
ec2_spec = {
  "web-server" = {
    instance_type = var.environment == "prod" ? "t3.large" : "t3.small"
    root_volume_size = var.environment == "prod" ? 100 : 20
    backup_retention = var.environment == "prod" ? 30 : 7
  }
}
```

### **Module Chaining**
```hcl
# Chain modules together
vpc_spec = {
  main = { cidr = "10.0.0.0/16" }
}

alb_spec = {
  web-alb = { 
    vpc_name = "main-vpc"                    # References VPC
  }
}

ec2_spec = {
  web-server = {
    vpc_name = "main-vpc"                    # References same VPC
    alb_name = "web-alb"                     # References ALB
    enable_alb_integration = true
  }
}
```

### **Dynamic Configuration**
```hcl
# Generate configurations programmatically
locals {
  web_servers = {
    for i in range(3) : "web-server-${i+1}" => {
      instance_type = "t3.medium"
      availability_zone = data.aws_availability_zones.available.names[i]
    }
  }
}

# Use in module
module "ec2_instance" {
  for_each = local.web_servers
  # ... configuration
}
```

## 🛠️ Customization and Extension

### **Adding Custom User Data**
```bash
# userdata-linux.sh - Customize server initialization
#!/bin/bash
ENVIRONMENT="${environment}"
HOSTNAME="${hostname}"

# Install application-specific software
yum install -y docker
systemctl start docker

# Deploy your application
docker run -d -p 80:80 myapp:latest
```

### **Custom Module Integration**
```hcl
# Add your own modules alongside base modules
module "custom_monitoring" {
  source = "./modules/monitoring"
  
  # Reference other modules
  instance_ids = [for k, v in module.ec2_instance : v.instance_id]
  alb_arns     = [for k, v in module.alb : v.alb_arn]
}
```

## 📋 Best Practices

### **Configuration Management**
- ✅ **Keep main.tf environment-agnostic** - Same logic across environments
- ✅ **Use terraform.tfvars for differences** - Environment-specific values only
- ✅ **Leverage for_each for scaling** - Deploy multiple resources efficiently
- ✅ **Use reference variables** - Link modules together cleanly

### **Module Organization**
- ✅ **One concern per module** - EC2, ALB, RDS as separate modules
- ✅ **Consistent naming** - Use environment suffixes everywhere
- ✅ **Output important values** - Make module outputs available for linking
- ✅ **Version your modules** - Pin to specific versions for stability

### **Environment Strategy**
- ✅ **Start with dev** - Test configurations in development first
- ✅ **Promote through environments** - Dev → Staging → Production
- ✅ **Use workspaces** - Isolate state between environments
- ✅ **Automate with CI/CD** - Use GitHub Actions for deployments

## 🚀 Deployment Workflows

### **Local Development**
```bash
# Quick development cycle
cd environments/dev
terraform plan                    # Review changes
terraform apply                   # Deploy to dev
terraform output                  # Get resource information
```

### **CI/CD Pipeline**
```bash
# Automated deployment via GitHub Actions
# 1. Push changes to repository
# 2. GitHub Actions runs terraform plan
# 3. Manual approval for apply
# 4. Terraform apply with environment isolation
```

### **Multi-Environment Promotion**
```bash
# Promote tested configuration
# 1. Test in dev environment
# 2. Deploy to staging with production-like sizing
# 3. Run integration tests
# 4. Deploy to production with approval gates
```

## 📚 Documentation

- **[Architecture Guide](docs/ARCHITECTURE.md)** - Technical architecture details
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Step-by-step deployment instructions  
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[ALB Log Cleanup](docs/ALB_LOG_CLEANUP.md)** - Handling S3 bucket cleanup

## 🆘 Getting Help

### **Common Tasks**
- **Adding new modules**: Follow the "Adding New Base Modules" section
- **Linking modules**: Use reference variables and outputs
- **Environment differences**: Modify terraform.tfvars only
- **Scaling resources**: Use for_each with multiple configurations

### **Troubleshooting**
- **Module not found**: Check source paths and module availability
- **Reference errors**: Verify module outputs and variable names
- **Environment issues**: Confirm workspace and variable settings
- **Deployment failures**: Check logs and module documentation

## 🎯 Summary

This Terraform Infrastructure Orchestrator enables you to:

1. **🧩 Orchestrate multiple base modules** with minimal configuration
2. **🔄 Deploy batch resources** using for_each patterns  
3. **🔗 Link modules together** using reference variables
4. **🌍 Manage multiple environments** with workspace isolation
5. **📦 Add new modules easily** following established patterns
6. **🎛️ Configure everything** through terraform.tfvars files

**Start building your infrastructure today** - clone this repository, configure your terraform.tfvars, and deploy! 🚀