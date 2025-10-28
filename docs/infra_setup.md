# Infrastructure Setup Guide

A **production-ready Terraform orchestrator** with GitOps workflow that acts as a wrapper around base infrastructure modules, enabling teams to build complex, multi-environment infrastructure using reusable components with automated branch-based promotion.

## What is This Repository?

This repository is an **Infrastructure Orchestrator with GitOps Workflow** that:

- **Wraps base modules** - Downloads and orchestrates multiple Terraform base modules
- **Simplifies infrastructure** - Provides high-level abstractions for complex deployments  
- **Multi-environment ready** - Supports dev, staging, and production with workspace isolation
- **GitOps branch promotion** - Automated dev → staging → production workflow
- **Batch deployments** - Deploy multiple resources in one call using `for_each`
- **Configuration-driven** - Define entire infrastructure through environment-specific tfvars files
- **Built-in approvals** - Team reviews for staging/production, terraform apply approval for production

## Current Solution: CloudFront + ALB + WAF Architecture

This orchestrator currently deploys a **production-ready web application architecture** with:

### **What's Deployed:**
- **CloudFront CDN** - Global content delivery with SSL termination
- **Application Load Balancer** - High-availability load balancing
- **Web Application Firewall (WAF)** - Advanced security protection with AWS managed rules
- **EC2 Instances** - Linux (Apache) and Windows (IIS) web servers
- **Security Groups** - CloudFront-only access, no direct internet access

### **Key Features:**
- **SSL Termination at CloudFront** - Better performance, global SSL
- **Automatic Scaling** - ALB with health checks and target groups
- **Advanced Security** - WAF with SQL injection, XSS, bot protection, rate limiting, geo-blocking
- **Multi-OS Support** - Both Linux and Windows web servers
- **Zero-Downtime Deployments** - Blue-green deployment ready
- **Comprehensive Logging** - WAF logs with configurable retention periods

### **Traffic Flow:**
```
User → CloudFront (HTTPS/443) → ALB (HTTP/80) → EC2 (HTTP/80)
       ↑                        ↑               ↑
   SSL at Edge            Load Balancing    Web Servers
   Global CDN             Health Checks     Auto-scaling
   WAF Protection         Target Groups     Apache/IIS
```

## Web Application Firewall (WAF) Protection

### **WAF Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│                    WAF Security Layers                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Internet Traffic                                           │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────────────┐                                        │
│  │      WAF        │ ← Web Application Firewall            │
│  │  (CloudFront)   │   • AWS Managed Rules                 │
│  └─────────┬───────┘   • Custom Security Rules             │
│            │           • Rate Limiting                     │
│            │           • Geo-blocking                      │
│            │           • Bot Protection                    │
│            ▼                                               │
│  ┌─────────────────┐                                        │
│  │   CloudFront    │ ← Content Delivery Network            │
│  │   Distribution  │   • Global Edge Locations             │
│  └─────────┬───────┘   • SSL/TLS Termination               │
│            │           • Caching & Performance             │
│            ▼                                               │
│  ┌─────────────────┐                                        │
│  │      ALB        │ ← Application Load Balancer           │
│  │   (HTTP/80)     │   • Health Checks                     │
│  └─────────┬───────┘   • Target Group Management           │
│            │                                               │
│            ▼                                               │
│  ┌─────────────────┐   ┌─────────────────┐                 │
│  │   EC2 Linux     │   │  EC2 Windows    │ ← Web Servers   │
│  │   (Apache)      │   │    (IIS)        │                 │
│  └─────────────────┘   └─────────────────┘                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### **WAF Security Features:**

#### **AWS Managed Rules (Enabled):**
- **Common Rule Set** - Core web application protection
- **Known Bad Inputs** - Malicious input patterns and payloads
- **SQL Injection Protection** - Prevents SQL injection attacks
- **Cross-Site Scripting (XSS)** - Blocks XSS attempts
- **IP Reputation** - Blocks traffic from known malicious IPs
- **Linux/Windows Rule Sets** - OS-specific attack protection
- **Bot Control** - Advanced bot detection and mitigation
- **Anonymous IP Blocking** - Blocks VPNs, proxies, Tor exit nodes

#### **Custom Security Rules:**

**Development Environment:**
```hcl
# Basic rate limiting
rate_limit = 300 requests per 5 minutes per IP
geo_blocking = ["CN", "RU", "KP", "IR", "SY"]
logging_retention = 180 days
```

**Staging Environment:**
```hcl
# Production-like security testing
rate_limit = 500 requests per 5 minutes per IP
geo_blocking = ["CN", "RU", "KP"]
logging_retention = 90 days
suspicious_user_agents = blocked
```

**Production Environment:**
```hcl
# Maximum security configuration
rate_limit = 200 requests per 5 minutes per IP
geo_blocking = ["CN", "RU", "KP", "IR", "SY", "CU", "SD"]
logging_retention = 365 days
suspicious_user_agents = blocked
malicious_ip_sets = comprehensive_blocking
```

#### **WAF Monitoring & Logging:**
- **CloudWatch Metrics** - Real-time security metrics
- **Sampled Requests** - Detailed request analysis
- **Custom Dashboards** - Security monitoring dashboards
- **Automated Alerts** - Threshold-based notifications
- **Log Retention** - Environment-specific retention policies

#### **IP Set Management:**
```hcl
# Trusted office IPs (allowed)
trusted_office_ips = [
  "203.0.113.0/24",    # Corporate office
  "198.51.100.0/24",   # Branch office
  "49.207.205.136/32"  # VPN gateway
]

# Blocked malicious IPs
blocked_malicious_ips = [
  "192.0.2.0/24"       # Known attack sources
]

# Partner/vendor IPs (production only)
partner_ips = [
  "203.0.114.0/24"     # Trusted partners
]
```

### **WAF Configuration by Environment:**

| Feature | Development | Staging | Production |
|---------|-------------|---------|------------|
| **Rate Limiting** | 300 req/5min | 500 req/5min | 200 req/5min |
| **Geo-blocking** | 5 countries | 3 countries | 7 countries |
| **AWS Managed Rules** | 7 rule sets | 7 rule sets | 10 rule sets |
| **Custom Rules** | 2 rules | 2 rules | 3 rules |
| **Log Retention** | 180 days | 90 days | 365 days |
| **IP Sets** | 2 sets | 2 sets | 3 sets |
| **Bot Protection** | Enabled | Enabled | Enhanced |

### **WAF Benefits:**
- **Multi-layer Security** - Protection at CloudFront edge
- **Global Protection** - Security applied at all edge locations
- **Low Latency** - Blocking happens at edge, not origin
- **Scalable** - Handles traffic spikes automatically
- **Visibility** - Comprehensive logging and monitoring
- **Cost Effective** - Pay only for requests processed
- **Manageable** - AWS managed rules with automatic updates

## Architecture Overview

### **Infrastructure Orchestrator Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│                 Terraform Orchestrator                      │
│                    (This Repository)                        │
├─────────────────────────────────────────────────────────────┤
│  Root Directory:                                            │
│  ├── main.tf              ← Orchestrates base modules      │
│  ├── variables.tf         ← Variable definitions           │
│  ├── outputs.tf           ← Output definitions             │
│  ├── tf-*-base-module/    ← Local base modules             │
│  │   ├── tf-alb-main/     ← ALB module                     │
│  │   ├── tf-cf-base-module/ ← CloudFront module            │
│  │   └── tf-waf-base-module/ ← WAF module                  │
│  └── tfvars/              ← Environment configurations     │
│      ├── dev-terraform.tfvars    ← Dev configs             │
│      ├── stg-terraform.tfvars    ← Staging configs         │
│      └── prod-terraform.tfvars   ← Production configs      │
└─────────────────────┬───────────────────────────────────────┘
                      │ Downloads & Uses
┌─────────────────────▼───────────────────────────────────────┐
│                 Base Modules                                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   EC2 Module    │  │   ALB Module    │  │ CloudFront   │ │
│  │ (External Repo) │  │  (Local)        │  │   (Local)    │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### **Current Deployment Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│                    Production Traffic Flow                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  User (Browser)                                             │
│       │ HTTPS/443                                           │
│       ▼                                                     │
│  ┌─────────────────┐                                        │
│  │   CloudFront    │ ← Global CDN with SSL termination     │
│  │   (HTTPS/443)   │   • SSL certificates                  │
│  └─────────┬───────┘   • Global edge locations             │
│            │ HTTP/80   • DDoS protection                   │
│            ▼           • Caching                           │
│  ┌─────────────────┐                                        │
│  │      ALB        │ ← Application Load Balancer           │
│  │   (HTTP/80)     │   • SSL termination at CloudFront    │
│  └─────────┬───────┘   • Health checks                     │
│            │ HTTP/80   • Target group management           │
│            ▼                                               │
│  ┌─────────────────┐   ┌─────────────────┐                 │
│  │   EC2 Linux     │   │  EC2 Windows    │ ← Web servers   │
│  │   (Apache/80)   │   │   (IIS/80)      │   • HTTP only   │
│  └─────────────────┘   └─────────────────┘   • Auto-scaling│
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### **Security Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│                    Security Layers                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐                                        │
│  │      WAF        │ ← Web Application Firewall            │
│  │  (CloudFront)   │   • SQL injection protection         │
│  └─────────┬───────┘   • XSS protection                    │
│            │           • Rate limiting                     │
│            ▼           • Geo-blocking                      │
│  ┌─────────────────┐                                        │
│  │   CloudFront    │ ← Content Delivery Network            │
│  │  Security Groups│   • DDoS protection                   │
│  └─────────┬───────┘   • SSL/TLS encryption               │
│            │           • Origin access control            │
│            ▼                                               │
│  ┌─────────────────┐                                        │
│  │      ALB        │ ← Load Balancer Security              │
│  │  Security Groups│   • CloudFront IP whitelist          │
│  └─────────┬───────┘   • No direct internet access        │
│            │           • VPC isolation                    │
│            ▼                                               │
│  ┌─────────────────┐   ┌─────────────────┐                 │
│  │   EC2 Linux     │   │  EC2 Windows    │ ← Instance Security│
│  │  Security Groups│   │ Security Groups │   • Private subnets│
│  └─────────────────┘   └─────────────────┘   • ALB access only│
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Repository Structure

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
├── shared/                            # Common backend configuration
│   ├── backend-common.hcl             # Common backend config for all environments
│   └── README.md                      # Backend documentation
├── scripts/                           # GitOps setup scripts
├── docs/                              # Documentation
├── .github/workflows/                 # GitOps CI/CD pipelines
├── Makefile                           # Simple deployment commands
├── deploy.sh                          # Local deployment script
└── .gitignore                         # Git ignore rules
```

## GitOps Branch Structure and Workflow

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

## Quick Start

### 1. Clone and Setup
```bash
git clone <repository-url>
cd terraform-infra-orchestrator

# Configure your shared services account ID
nano config/aws-accounts.json

# Setup backend resources in shared services account
./scripts/setup-backend-per-account.sh
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

## How Base Module Integration Works

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

## Module Linking and Reference Variables

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
# Define WAF first
waf_spec = {
  cloudfront-waf = {
    scope = "CLOUDFRONT"
    enabled_aws_managed_rules = [
      "common_rule_set",
      "sqli_rule_set", 
      "bot_control"
    ]
    custom_rules = [
      {
        name = "RateLimit"
        priority = 11
        action = "block"
        type = "rate_based"
        limit = 300
      }
    ]
  }
}

# Define ALB
alb_spec = {
  web-alb = {
    name = "web-alb"
    vpc_name = "dev-vpc"
  }
}

# Reference ALB and WAF in CloudFront configuration
cloudfront_spec = {
  web-cf = {
    distribution_name = "web-app-distribution"
    alb_origin = "web-alb"           # References the ALB above
    waf_key = "cloudfront-waf"       # References the WAF above
    price_class = "PriceClass_100"
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

## Adding New Base Modules

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

## Multi-Environment Management

### **Common Backend with Workspace Isolation**
All environments use a single S3 bucket and DynamoDB table with Terraform workspaces for isolation:

```bash
# Initialize with common backend (same for all environments)
terraform init -backend-config=shared/backend-common.hcl

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

### **Backend Architecture**
```
Shared Services Account (Centralized Backend)
├── S3 Bucket: terraform-state-central-multi-env
│   ├── environments/
│   │   ├── dev/terraform.tfstate
│   │   ├── staging/terraform.tfstate
│   │   └── production/terraform.tfstate
│
└── DynamoDB Table: terraform-state-locks-common

Environment Accounts (Cross-Account Access)
├── Dev Account (221106935066) → Accesses shared backend
├── Staging Account (137617557860) → Accesses shared backend  
└── Production Account → Accesses shared backend
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

## Batch Deployments with for_each

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

## Advanced Configuration Patterns

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

## Development Workflow

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

## Deployment Workflows

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

## Customization and Extension

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

## Best Practices

### **Configuration Management**
- **Keep main.tf environment-agnostic** - Same logic across environments
- **Use environment-specific tfvars** - Different values per environment
- **Leverage for_each for scaling** - Deploy multiple resources efficiently
- **Use reference variables** - Link modules together cleanly

### **Module Organization**
- **One concern per module** - EC2, ALB, RDS as separate modules
- **Consistent naming** - Use environment suffixes everywhere
- **Output important values** - Make module outputs available for linking
- **Version your modules** - Pin to specific versions for stability

### **Environment Strategy**
- **Start with dev** - Test configurations in development first
- **Promote through environments** - Dev → Staging → Production
- **Use workspaces** - Isolate state between environments
- **Automate with GitOps** - Use GitHub Actions for deployments

## Pipeline and Deployment Guide

### **Pipeline Triggers and Workflow**

#### **Automatic Triggers:**
- **Dev Branch Push**: Automatically runs setup → plan → apply
- **Staging/Production Branch Push**: Automatically runs setup → plan → apply
- **Pull Requests to Staging/Production**: Runs plan-only for review

#### **Manual Triggers:**
You can manually trigger the pipeline from any branch:
1. Go to **GitHub Actions** → **"Terraform Infrastructure Deploy"** → **"Run workflow"**
2. Select options:
   - **Branch**: Choose your branch (dev, staging, production)
   - **Environment**: Choose target environment (dev, staging, production)
   - **Action**: Choose pipeline action:
     - `setup-only`: Just create S3 buckets and DynamoDB tables
     - `plan-only`: Plan without applying changes
     - `plan-and-apply`: Full deployment pipeline
     - `destroy`: Destroy infrastructure
   - **Skip setup**: Check if backends already exist

### **Environment Protection and Approvals**

#### **Current Configuration:**
- **Dev Environment**: No approval required, auto-deploys
- **Staging Environment**: **Requires GitHub Environment Protection Setup**
- **Production Environment**: **Requires GitHub Environment Protection Setup**

#### **Setting Up Environment Protection and Approvers:**

1. **Go to Repository Settings**:
   ```
   GitHub Repository → Settings → Environments
   ```

2. **Create Environment Protection Rules**:

   **For Staging Environment:**
   ```
   Environment name: staging
   Required reviewers: Add your team members
   Wait timer: 0 minutes (or set delay)
   Deployment branches: Only staging branch
   ```

   **For Production Environment:**
   ```
   Environment name: production
   Required reviewers: Add senior team members/leads
   Wait timer: 5 minutes (cooling period)
   Deployment branches: Only production branch
   ```

   **For Production Apply Approval:**
   ```
   Environment name: production-apply-approval
   Required reviewers: Add infrastructure team leads
   Wait timer: 0 minutes
   Deployment branches: Only production branch
   ```

3. **Add Reviewers**:
   - Click **"Add required reviewers"**
   - Add GitHub usernames or teams
   - Minimum 1-2 reviewers recommended

### **Creating PRs for Staging Environment**

#### **Why No Automatic PR Creation:**
Your current pipeline is configured for **direct branch deployment**, not PR-based workflow. Here are your options:

#### **Option 1: Manual PR Creation (Current Setup)**
```bash
# After dev deployment succeeds, manually create PR
git checkout staging
git merge dev
git push origin staging

# Or create PR via GitHub UI
# GitHub → Pull Requests → New → base: staging ← compare: dev
```

#### **Option 2: Enable GitOps Auto-Promotion**
You have a `gitops-promotion.yml` workflow that can auto-create PRs. To enable it:

1. **Check GitOps Configuration**:
   ```bash
   # Verify config/gitops-environments.json exists and is configured
   cat config/gitops-environments.json
   ```

2. **Enable Auto-Promotion**:
   The GitOps workflow should automatically create PRs from dev → staging → production when dev deployment succeeds.

#### **Option 3: Switch to PR-Only Workflow**
Modify the pipeline to only deploy via PRs:

```yaml
# In .github/workflows/terraform-deploy.yml
on:
  pull_request:
    branches:
      - dev        # Add this for dev PRs
      - staging
      - production
  # Remove push triggers if you want PR-only workflow
```

### **Recommended Workflow for Your Team**

#### **For Development:**
```bash
# 1. Work on feature branch
git checkout -b feature/new-infrastructure
# Make changes to main.tf and tfvars files
git commit -m "feat: add new infrastructure"
git push origin feature/new-infrastructure

# 2. Create PR to dev branch
# GitHub → Pull Requests → New → base: dev ← compare: feature/new-infrastructure

# 3. After PR approval and merge, dev auto-deploys
```

#### **For Staging Deployment:**
```bash
# Option A: Manual PR (Current)
git checkout staging
git merge dev
git push origin staging

# Option B: GitHub UI PR
# GitHub → Pull Requests → New → base: staging ← compare: dev
# Add reviewers → Create PR → Approve → Merge
# Pipeline auto-deploys to staging after merge
```

#### **For Production Deployment:**
```bash
# Create PR from staging to production
git checkout production  
git merge staging
git push origin production

# Or via GitHub UI with required approvals
```

### **Pipeline Status and Monitoring**

#### **Check Pipeline Status:**
```bash
# View recent workflow runs
GitHub → Actions → Select workflow → View runs

# Check specific environment deployment
GitHub → Actions → Filter by branch (dev/staging/production)
```

#### **Environment URLs:**
After successful deployment, check the workflow summary for:
- **ALB Endpoints**: Load balancer URLs
- **EC2 Instance Details**: Instance IDs and IPs
- **Terraform Outputs**: All resource details

### **Troubleshooting Common Issues**

#### **S3 Bucket Errors:**
- **Fixed**: Pipeline now automatically creates S3 buckets
- If still occurring: Run workflow with `setup-only` action first

#### **Backend Configuration Issues:**
- Check if `shared/backend-common.hcl` exists and is properly configured
- Run setup stage to create common backend resources and workspaces

#### **Permission Issues:**
- Verify AWS credentials in repository secrets
- Check IAM roles have proper permissions
- Ensure `OrganizationAccountAccessRole` exists in target accounts

#### **Module Download Failures:**
- Verify `PRIVATE_REPO_TOKEN` has access to module repositories
- Check module repository URLs in main.tf

## Documentation

- **[GitOps Setup Guide](docs/GITOPS_SETUP.md)** - Detailed setup instructions for GitOps workflow
- **[Environment-Specific Configurations](docs/ENVIRONMENT_SPECIFIC_CONFIGS.md)** - Managing different VPCs, configs per environment
- **[Architecture Guide](docs/ARCHITECTURE.md)** - Technical architecture details
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Step-by-step deployment instructions  
- **[GitHub Actions Setup](docs/GITHUB_ACTIONS_SETUP.md)** - GitHub Actions configuration guide
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## Getting Help

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

## Summary

This GitOps Terraform Infrastructure Orchestrator enables you to:

1. **Orchestrate multiple base modules** with minimal configuration
2. **Deploy batch resources** using for_each patterns  
3. **Link modules together** using reference variables
4. **Manage multiple environments** with workspace isolation and GitOps promotion
5. **Add new modules easily** following established patterns
6. **Configure everything** through environment-specific tfvars files
7. **Automate deployments** with GitOps branch-based promotion workflow

**Start building your infrastructure today** - clone this repository, configure your environment-specific tfvars files, and commit to dev branch!