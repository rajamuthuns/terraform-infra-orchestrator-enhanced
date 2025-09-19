# GitOps Terraform Infrastructure Orchestrator

A **production-ready Terraform orchestrator** with GitOps workflow that acts as a wrapper around base infrastructure modules, enabling teams to build complex, multi-environment infrastructure using reusable components with automated branch-based promotion.

## 🎯 What is This Repository?

This repository is an **Infrastructure Orchestrator with GitOps Workflow** that:

- 🧩 **Wraps base modules** - Downloads and orchestrates multiple Terraform base modules
- 🏗️ **Simplifies infrastructure** - Provides high-level abstractions for complex deployments  
- 🌍 **Multi-environment ready** - Supports dev, staging, and production with workspace isolation
- 🔄 **GitOps branch promotion** - Automated dev → staging → production workflow
- 📦 **Batch deployments** - Deploy multiple resources in one call using `for_each`
- 🎛️ **Configuration-driven** - Define entire infrastructure through environment-specific tfvars files
- 🛡️ **Built-in approvals** - Team reviews for staging/production, terraform apply approval for production

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                 Terraform Orchestrator                      │
│                    (This Repository)                        │
├─────────────────────────────────────────────────────────────┤
│  Root Directory:                                            │
│  ├── main.tf              ← Orchestrates base modules      │
│  ├── variables.tf         ← Variable definitions           │
│  ├── outputs.tf           ← Output definitions             │
│  └── tfvars/              ← Environment configurations     │
│      ├── dev-terraform.tfvars    ← Dev configs             │
│      ├── stg-terraform.tfvars    ← Staging configs         │
│      └── prod-terraform.tfvars   ← Production configs      │
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

## 📁 Repository Structure

```
terraform-infra-orchestrator/
├── README.md                          # This guide
├── main.tf                            # Main Terraform configuration (environment-agnostic)
├── variables.tf                       # Variable definitions
├── outputs.tf                         # Output definitions
├── backend.tf                         # Backend configuration
├── userdata/                          # Server initialization scripts
│   ├── userdata-linux.sh              # Linux server initialization script
│   ├── userdata-windows.ps1           # Windows server initialization script
│   └── README.md                      # Userdata documentation
├── tfvars/                            # Environment-specific configurations
│   ├── dev-terraform.tfvars           # Development environment values
│   ├── stg-terraform.tfvars           # Staging environment values
│   └── prod-terraform.tfvars          # Production environment values
├── config/                            # GitOps configuration
│   ├── aws-accounts.json              # AWS account mappings
│   └── gitops-environments.json       # Environment-specific settings
├── shared/                            # Backend configurations
│   ├── backend-dev.hcl                # Dev backend config
│   ├── backend-staging.hcl            # Staging backend config
│   └── backend-prod.hcl               # Production backend config
├── scripts/                           # GitOps setup scripts
├── docs/                              # Documentation
├── .github/workflows/                 # GitOps CI/CD pipelines
├── Makefile                           # Simple deployment commands
├── deploy.sh                          # Local deployment script
└── .gitignore                         # Git ignore rules
```

## 🌍 GitOps Branch Structure and Workflow

### **Branch-Environment Mapping**
Each branch corresponds to a specific environment and uses the appropriate tfvars file:

```
dev branch        → Development environment   → tfvars/dev-terraform.tfvars
staging branch    → Staging environment      → tfvars/stg-terraform.tfvars  
production branch → Production environment   → tfvars/prod-terraform.tfvars
```

### **GitOps Promotion Workflow**

```
┌─────────────────────────────────────────────────────────────┐
│                    GitOps Workflow                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Developer commits all configs to dev branch            │
│     ├── main.tf (infrastructure code)                      │
│     ├── tfvars/dev-terraform.tfvars (dev configs)          │
│     ├── tfvars/stg-terraform.tfvars (staging configs)      │
│     └── tfvars/prod-terraform.tfvars (production configs)  │
│                                                             │
│  2. Dev deployment uses tfvars/dev-terraform.tfvars        │
│     └── Automatic deployment, no approvals                 │
│                                                             │
│  3. Auto-promotion to staging branch                       │
│     ├── Promotes all files to staging branch               │
│     ├── Staging deployment uses tfvars/stg-terraform.tfvars│
│     └── Requires team approval                             │
│                                                             │
│  4. Auto-promotion to production branch                    │
│     ├── Promotes all files to production branch            │
│     ├── Production uses tfvars/prod-terraform.tfvars       │
│     ├── Requires team approval                             │
│     └── Additional terraform apply approval                │
│                                                             │
│  5. Infrastructure deployed across all environments! 🎉    │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### 1. Clone and Setup
```bash
git clone <repository-url>
cd terraform-infra-orchestrator

# Create GitOps branches
./scripts/create-gitops-branches.sh

# Setup branch protection and environments
./scripts/setup-branch-protection.sh
./scripts/setup-github-environments.sh
```

### 2. Configure Your Infrastructure
```bash
# Create environment-specific configurations
nano tfvars/dev-terraform.tfvars      # Development settings
nano tfvars/stg-terraform.tfvars      # Staging settings  
nano tfvars/prod-terraform.tfvars     # Production settings
```

### 3. Deploy with GitOps
```bash
# Commit all configurations to dev branch
git add .
git commit -m "feat: add new infrastructure with all environment configs"
git push origin dev

# GitOps workflow automatically:
# 1. Deploys to dev using tfvars/dev-terraform.tfvars
# 2. Creates PR to staging (uses tfvars/stg-terraform.tfvars)
# 3. Creates PR to production (uses tfvars/prod-terraform.tfvars)
```

## 🧩 How Base Module Integration Works

### **Module Download and Usage**
The orchestrator automatically downloads and uses base modules:

```hcl
# In main.tf
module "ec2_instance" {
  source = "git::https://github.com/your-org/ec2-base-module.git?ref=v1.0.0"
  
  for_each = var.ec2_spec              # Deploy multiple instances
  
  # Pass configuration from environment-specific tfvars
  name_prefix   = each.key
  instance_type = each.value.instance_type
  vpc_name      = each.value.vpc_name
  # ... other parameters
}
```

### **Configuration-Driven Deployment**
Define your entire infrastructure in environment-specific tfvars files:

```hcl
# tfvars/dev-terraform.tfvars - Development configuration
ec2_spec = {
  "web-server-1" = {
    instance_type = "t3.micro"
    vpc_name      = "dev-vpc"
    ami_name      = "amzn2-ami-hvm-*"
    # ... other settings
  }
}

# tfvars/stg-terraform.tfvars - Staging configuration
ec2_spec = {
  "web-server-1" = {
    instance_type = "t3.small"
    vpc_name      = "staging-vpc"
    ami_name      = "amzn2-ami-hvm-*"
    # ... other settings
  }
}

# tfvars/prod-terraform.tfvars - Production configuration
ec2_spec = {
  "web-server-1" = {
    instance_type = "t3.medium"
    vpc_name      = "prod-vpc"
    ami_name      = "amzn2-ami-hvm-*"
    # ... other settings
  },
  "web-server-2" = {
    instance_type = "t3.medium"
    vpc_name      = "prod-vpc"
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
  source = "git::https://github.com/your-org/alb-base-module.git?ref=v1.0.0"
  for_each = var.alb_spec
  
  vpc_name = each.value.vpc_name
  name     = "${each.value.name}-${var.environment}"
}

# EC2 Module - References ALB output
module "ec2_instance" {
  source = "git::https://github.com/your-org/ec2-base-module.git?ref=v1.0.0"
  for_each = var.ec2_spec
  
  # Link to ALB target group
  enable_alb_integration = try(each.value.enable_alb_integration, false)
  alb_target_group_arns  = try(each.value.enable_alb_integration, false) ? 
    [module.alb[each.value.alb_name].default_target_group_arn] : []
}
```

### **Cross-Module References in tfvars**
```hcl
# tfvars/dev-terraform.tfvars
# Define ALB first
alb_spec = {
  web-alb = {
    name = "web-alb"
    vpc_name = "dev-vpc"
  }
}

# Reference ALB in EC2 configuration
ec2_spec = {
  "web-server" = {
    enable_alb_integration = true
    alb_name = "web-alb"              # References the ALB above
    instance_type = "t3.micro"
    vpc_name = "dev-vpc"
  }
}
```

## 📦 Adding New Base Modules

### **Step 1: Add Module to main.tf**
```hcl
# Add new module block
module "rds_instance" {
  source = "git::https://github.com/your-org/rds-base-module.git?ref=v1.0.0"
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

### **Step 4: Configure in Environment-Specific tfvars**
```hcl
# tfvars/dev-terraform.tfvars
rds_spec = {
  "app-database" = {
    db_name        = "appdb"
    engine         = "mysql"
    instance_class = "db.t3.micro"
    vpc_name       = "dev-vpc"
    ec2_ref        = "web-server"    # Reference to EC2 for security group
  }
}

# tfvars/stg-terraform.tfvars
rds_spec = {
  "app-database" = {
    db_name        = "appdb"
    engine         = "mysql"
    instance_class = "db.t3.small"
    vpc_name       = "staging-vpc"
    ec2_ref        = "web-server"
  }
}

# tfvars/prod-terraform.tfvars
rds_spec = {
  "app-database" = {
    db_name        = "appdb"
    engine         = "mysql"
    instance_class = "db.r5.large"
    vpc_name       = "prod-vpc"
    ec2_ref        = "web-server"
    multi_az       = true
    backup_retention_period = 30
  }
}
```

## 🌍 Multi-Environment Management

### **Terraform Workspaces**
Each environment uses its own workspace for complete isolation:

```bash
# Development
terraform workspace select dev || terraform workspace new dev
terraform apply -var-file=tfvars/dev-terraform.tfvars

# Staging  
terraform workspace select staging || terraform workspace new staging
terraform apply -var-file=tfvars/stg-terraform.tfvars

# Production
terraform workspace select production || terraform workspace new production
terraform apply -var-file=tfvars/prod-terraform.tfvars
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

## 🔄 Batch Deployments with for_each

### **Deploy Multiple Resources in One Call**
```hcl
# tfvars/dev-terraform.tfvars - Deploy 2 web servers for development
ec2_spec = {
  "web-server-1" = { instance_type = "t3.micro", az = "us-east-1a" },
  "web-server-2" = { instance_type = "t3.micro", az = "us-east-1b" }
}

# tfvars/stg-terraform.tfvars - Deploy 3 web servers for staging
ec2_spec = {
  "web-server-1" = { instance_type = "t3.small", az = "us-east-1a" },
  "web-server-2" = { instance_type = "t3.small", az = "us-east-1b" },
  "web-server-3" = { instance_type = "t3.small", az = "us-east-1c" }
}

# tfvars/prod-terraform.tfvars - Deploy 5 web servers for production
ec2_spec = {
  "web-server-1" = { instance_type = "t3.medium", az = "us-east-1a" },
  "web-server-2" = { instance_type = "t3.medium", az = "us-east-1b" },
  "web-server-3" = { instance_type = "t3.large",  az = "us-east-1c" },
  "app-server-1" = { instance_type = "t3.xlarge", az = "us-east-1a" },
  "app-server-2" = { instance_type = "t3.xlarge", az = "us-east-1b" }
}
```

## 🎛️ Advanced Configuration Patterns

### **Environment-Specific Sizing**
```hcl
# tfvars/dev-terraform.tfvars - Cost-optimized for development
ec2_spec = {
  "web-server" = {
    instance_type = "t3.micro"
    root_volume_size = 20
    backup_retention = 7
  }
}

# tfvars/stg-terraform.tfvars - Production-like for testing
ec2_spec = {
  "web-server" = {
    instance_type = "t3.small"
    root_volume_size = 50
    backup_retention = 14
  }
}

# tfvars/prod-terraform.tfvars - Production-grade resources
ec2_spec = {
  "web-server" = {
    instance_type = "t3.large"
    root_volume_size = 100
    backup_retention = 30
  }
}
```

### **Module Chaining**
```hcl
# Chain modules together in all environment tfvars files
vpc_spec = {
  main = { cidr = "10.0.0.0/16" }  # Different CIDRs per environment
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

## 📝 Development Workflow

### **Step 1: Create All Environment Configurations**
```bash
# 1. Switch to dev branch
git checkout dev

# 2. Infrastructure code is already in root main.tf (environment-agnostic)
# 3. Create environment-specific configurations in tfvars/

# Create dev configuration
cat > tfvars/dev-terraform.tfvars << EOF
project_name = "myapp"
environment = "dev"
account_id = "123456789012"

# Dev-specific VPC and networking
alb_spec = {
  web-alb = {
    vpc_name = "dev-vpc"
    http_enabled = true
    https_enabled = false
    name = "web-alb"
  }
}

# Small, cost-effective resources
ec2_spec = {
  "web-server" = {
    enable_alb_integration = true
    alb_name = "web-alb"
    instance_type = "t3.micro"
    vpc_name = "dev-vpc"
    subnet_name = "dev-public-subnet-1"
    ami_name = "amzn2-ami-hvm-*-x86_64-gp2"
    os_type = "linux"
  }
}
EOF

# 4. Create staging configuration
cat > tfvars/stg-terraform.tfvars << EOF
project_name = "myapp"
environment = "staging"
account_id = "123456789013"

# Staging-specific VPC and networking
alb_spec = {
  web-alb = {
    vpc_name = "staging-vpc"
    http_enabled = true
    https_enabled = false
    name = "web-alb"
  }
}

# Production-like resources
ec2_spec = {
  "web-server" = {
    enable_alb_integration = true
    alb_name = "web-alb"
    instance_type = "t3.small"
    vpc_name = "staging-vpc"
    subnet_name = "staging-public-subnet-1"
    ami_name = "amzn2-ami-hvm-*-x86_64-gp2"
    os_type = "linux"
  }
}
EOF

# 5. Create production configuration
cat > tfvars/prod-terraform.tfvars << EOF
project_name = "myapp"
environment = "prod"
account_id = "123456789014"

# Production-specific VPC and networking
alb_spec = {
  web-alb = {
    vpc_name = "prod-vpc"
    http_enabled = false
    https_enabled = true
    name = "web-alb"
  }
}

# Production-grade resources
ec2_spec = {
  "web-server-1" = {
    enable_alb_integration = true
    alb_name = "web-alb"
    instance_type = "t3.medium"
    vpc_name = "prod-vpc"
    subnet_name = "prod-public-subnet-1"
    ami_name = "amzn2-ami-hvm-*-x86_64-gp2"
    os_type = "linux"
  },
  "web-server-2" = {
    enable_alb_integration = true
    alb_name = "web-alb"
    instance_type = "t3.medium"
    vpc_name = "prod-vpc"
    subnet_name = "prod-public-subnet-2"
    ami_name = "amzn2-ami-hvm-*-x86_64-gp2"
    os_type = "linux"
  }
}
EOF

# 6. Commit all configurations to dev branch
git add .
git commit -m "feat: add web server infrastructure with all environment configs"
git push origin dev
```

### **Step 2: Updating Configurations**
```bash
# To update any environment configuration
git checkout dev

# Update the specific environment tfvars file
nano tfvars/stg-terraform.tfvars   # Update staging config
nano tfvars/prod-terraform.tfvars  # Update production config

# Commit changes
git add .
git commit -m "config: update staging and production instance types"
git push origin dev

# GitOps workflow will promote the updated configs automatically
```

## 🚀 Deployment Workflows

### **GitOps Development**
```bash
# Complete development cycle

# Create all environment configs in dev branch
nano tfvars/dev-terraform.tfvars   # Development settings
nano tfvars/stg-terraform.tfvars   # Staging settings
nano tfvars/prod-terraform.tfvars  # Production settings

# Commit to dev branch
git add .
git commit -m "feat: add new infrastructure"
git push origin dev

# GitOps handles the rest automatically!
```

### **Manual Deployment**
```bash
# Using deployment script
./deploy.sh dev apply              # Deploy to development
./deploy.sh staging apply          # Deploy to staging
./deploy.sh production apply       # Deploy to production

# Using Makefile
make dev      # Deploy to development
make staging  # Deploy to staging
make prod     # Deploy to production
```

## 🛠️ Customization and Extension

### **Adding Custom User Data**
```bash
# userdata/userdata-linux.sh - Customize server initialization
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
- ✅ **Use environment-specific tfvars** - Different values per environment
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
- ✅ **Automate with GitOps** - Use GitHub Actions for deployments

## 📚 Documentation

- **[GitOps Setup Guide](docs/GITOPS_SETUP.md)** - Detailed setup instructions for GitOps workflow
- **[Environment-Specific Configurations](docs/ENVIRONMENT_SPECIFIC_CONFIGS.md)** - Managing different VPCs, configs per environment
- **[Architecture Guide](docs/ARCHITECTURE.md)** - Technical architecture details
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Step-by-step deployment instructions  
- **[GitHub Actions Setup](docs/GITHUB_ACTIONS_SETUP.md)** - GitHub Actions configuration guide
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## 🆘 Getting Help

### **Common Tasks**
- **Adding new modules**: Follow the "Adding New Base Modules" section
- **Linking modules**: Use reference variables and outputs
- **Environment differences**: Modify environment-specific tfvars files
- **Scaling resources**: Use for_each with multiple configurations

### **Troubleshooting**
- **Module not found**: Check source paths and module availability
- **Reference errors**: Verify module outputs and variable names
- **Environment issues**: Confirm workspace and tfvars file settings
- **Deployment failures**: Check logs and module documentation

## 🎯 Summary

This GitOps Terraform Infrastructure Orchestrator enables you to:

1. **🧩 Orchestrate multiple base modules** with minimal configuration
2. **🔄 Deploy batch resources** using for_each patterns  
3. **🔗 Link modules together** using reference variables
4. **🌍 Manage multiple environments** with workspace isolation and GitOps promotion
5. **📦 Add new modules easily** following established patterns
6. **🎛️ Configure everything** through environment-specific tfvars files
7. **🚀 Automate deployments** with GitOps branch-based promotion workflow

**Start building your infrastructure today** - clone this repository, configure your environment-specific tfvars files, and commit to dev branch! 🚀