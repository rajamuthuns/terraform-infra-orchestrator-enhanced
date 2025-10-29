# Infrastructure Setup Guide

Quick setup guide for the Terraform Infrastructure Orchestrator.

## What This Orchestrator Does

This repository is an **Infrastructure Orchestrator** that:
- **Wraps base modules** - Downloads and orchestrates multiple Terraform base modules
- **Simplifies infrastructure** - Provides high-level abstractions for complex deployments  
- **Multi-environment ready** - Supports dev, staging, and production with workspace isolation
- **Configuration-driven** - Define entire infrastructure through environment-specific tfvars files

## Current Solution: Web Application Architecture

This orchestrator deploys a **production-ready web application architecture** with:

### What's Deployed
- **CloudFront CDN** - Global content delivery with SSL termination
- **Application Load Balancer** - High-availability load balancing
- **Web Application Firewall (WAF)** - Advanced security protection
- **EC2 Instances** - Linux (Apache) and Windows (IIS) web servers
- **Security Groups** - CloudFront-only access, no direct internet access

### Traffic Flow
```
User → CloudFront (HTTPS/443) → ALB (HTTP/80) → EC2 (HTTP/80)
       ↑                        ↑               ↑
   SSL at Edge            Load Balancing    Web Servers
   Global CDN             Health Checks     Auto-scaling
   WAF Protection         Target Groups     Apache/IIS
```

## Prerequisites

### Required Tools
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Access to target AWS accounts
- **Security Group Quota Increase** (see [Security Group Quota Guide](security_group_quota_increase.md))

### AWS Account Structure
```
Organization Root
├── Shared Services Account (for backend)
├── Dev Account
├── Staging Account
└── Production Account
```

## Quick Start

### 1. Clone and Setup
```bash
git clone <repository-url>
cd terraform-infra-orchestrator

# Configure your AWS account IDs
nano config/aws-accounts.json
```

### 2. Setup Backend
```bash
# Setup backend resources in shared services account
./scripts/setup-backend-per-account.sh
```

### 3. Configure Infrastructure
```bash
# Create environment-specific configurations
nano tfvars/dev-terraform.tfvars      # Development settings
nano tfvars/stg-terraform.tfvars      # Staging settings  
nano tfvars/prod-terraform.tfvars     # Production settings
```

### 4. Deploy
```bash
# Initialize with shared backend
terraform init -backend-config=shared/backend-common.hcl

# Select environment workspace
terraform workspace select dev || terraform workspace new dev

# Deploy with environment-specific configuration
terraform apply -var-file=tfvars/dev-terraform.tfvars
```

## Repository Structure

```
tf-enhanced/
├── main.tf                            # Main orchestrator configuration
├── variables.tf                       # Variable definitions
├── outputs.tf                         # Output definitions
├── backend.tf                         # Backend configuration
├── tfvars/                            # Environment-specific configurations
│   ├── dev-terraform.tfvars           # Development environment
│   ├── stg-terraform.tfvars           # Staging environment
│   └── prod-terraform.tfvars          # Production environment
├── userdata/                          # Server initialization scripts
├── shared/                            # Common backend configuration
├── scripts/                           # Setup and validation scripts
├── docs/                              # Documentation
└── .github/workflows/                 # CI/CD pipelines
```

## Configuration Example

### Basic EC2 and ALB Configuration
```hcl
# tfvars/dev-terraform.tfvars
project_name = "myapp"
environment = "dev"

# ALB Configuration
alb_spec = {
  web-alb = {
    vpc_name = "dev-vpc"
    http_enabled = true
    https_enabled = false
    name = "web-alb"
  }
}

# EC2 Configuration with ALB Integration
ec2_spec = {
  "web-server" = {
    enable_alb_integration = true
    alb_name = "web-alb"              # References ALB above
    instance_type = "t3.micro"
    vpc_name = "dev-vpc"
    subnet_name = "dev-public-subnet-1"
    ami_name = "amzn2-ami-hvm-*-x86_64-gp2"
    os_type = "linux"
  }
}
```

## Environment-Specific Sizing

### Development
```hcl
ec2_spec = {
  "web-server" = {
    instance_type = "t3.micro"
    root_volume_size = 20
  }
}
```

### Staging
```hcl
ec2_spec = {
  "web-server" = {
    instance_type = "t3.small"
    root_volume_size = 50
  }
}
```

### Production
```hcl
ec2_spec = {
  "web-server-1" = {
    instance_type = "t3.medium"
    root_volume_size = 100
  },
  "web-server-2" = {
    instance_type = "t3.medium"
    root_volume_size = 100
  }
}
```

## Validation

### Test Deployment
```bash
# Test infrastructure and security
./scripts/test_cloudfront_security.sh

# Get orchestrated infrastructure outputs
terraform output
```

### Verify Resources
```bash
# Check ALB endpoints
terraform output alb_endpoints

# Check CloudFront distributions
terraform output cloudfront_endpoints

# Check complete architecture flow
terraform output architecture_flow
```

## Next Steps

After initial setup:
1. **Configure CI/CD** - See [GitHub Actions Setup](github_actions_setup.md)
2. **Understand Module Linking** - See [Module Linking Architecture](module_linking_architecture.md)
3. **Setup Shared Backend** - See [Shared Services Backend Setup](shared_services_backend_setup.md)
4. **Troubleshooting** - See [Troubleshooting Guide](troubleshooting.md)

## Common Commands

```bash
# Multi-Environment Deployment
terraform workspace select dev
terraform apply -var-file=tfvars/dev-terraform.tfvars

terraform workspace select staging
terraform apply -var-file=tfvars/stg-terraform.tfvars

terraform workspace select production
terraform apply -var-file=tfvars/prod-terraform.tfvars
```

This setup provides a foundation for managing complex, multi-module infrastructure deployments across multiple AWS accounts and environments.