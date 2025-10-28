# Terraform Infrastructure Orchestrator

A **production-ready Terraform orchestrator** that deploys CloudFront + ALB + WAF + EC2 architecture across multiple environments using reusable modules and GitOps workflow.

## 🚀 Quick Start

### Deploy to Development
```bash
terraform init -backend-config=shared/backend-common.hcl
terraform workspace select dev || terraform workspace new dev
terraform apply -var-file=tfvars/dev-terraform.tfvars
```

### Test Your Deployment
```bash
# Test WAF + CloudFront security
./scripts/validate-cloudfront.sh dev

# Get CloudFront URLs
terraform output cloudfront_endpoints
```

## 🏗️ Architecture

**Current Deployment:**
```
User → CloudFront (HTTPS) → WAF → ALB (HTTP) → EC2 (Linux/Windows)
       ↑                    ↑     ↑            ↑
   SSL Termination      Security  Load Balancing   Web Servers
   Global CDN          Protection  Health Checks    Apache/IIS
```

**Components:**
- **CloudFront CDN** - Global content delivery with SSL termination
- **Web Application Firewall** - SQL injection, XSS, bot protection, rate limiting
- **Application Load Balancer** - High-availability load balancing with health checks
- **EC2 Instances** - Linux (Apache) and Windows (IIS) web servers

## 📁 Repository Structure

```
terraform-infra-orchestrator/
├── main.tf                     # Main orchestrator configuration
├── variables.tf                # Variable definitions
├── outputs.tf                  # Output definitions
├── tfvars/                     # Environment configurations
│   ├── dev-terraform.tfvars    # Development environment
│   ├── stg-terraform.tfvars    # Staging environment
│   └── prod-terraform.tfvars   # Production environment
├── tf-*-base-module/           # Local base modules
│   ├── tf-alb-main/            # ALB module
│   ├── tf-cf-base-module/      # CloudFront module
│   └── tf-waf-base-module/     # WAF module
├── userdata/                   # Server initialization scripts
├── scripts/                    # Validation and testing scripts
├── docs/                       # Documentation
└── shared/                     # Common backend configuration
```

## 🌍 Multi-Environment Support

### Environment Configuration
| Environment | Instance Types | WAF Rate Limit | Storage | Logging |
|-------------|---------------|----------------|---------|---------|
| **Development** | t3.micro/small | 300 req/5min | 20-100GB | 180 days |
| **Staging** | t3.small/medium | 500 req/5min | 30-300GB | 90 days |
| **Production** | t3.medium/large+ | 200 req/5min | 50-500GB | 365 days |

### GitOps Workflow
```
dev branch        → Development environment   → tfvars/dev-terraform.tfvars
staging branch    → Staging environment      → tfvars/stg-terraform.tfvars  
production branch → Production environment   → tfvars/prod-terraform.tfvars
```

## 🔧 Configuration

### Adding New Resources
Edit the appropriate tfvars file:

```hcl
# tfvars/dev-terraform.tfvars
ec2_spec = {
  "new-server" = {
    instance_type = "t3.micro"
    vpc_name      = "dev-mig-target-vpc"
    ami_name      = "amzn2-ami-hvm-*-x86_64-gp2"
    os_type       = "linux"
  }
}
```

### Module Linking
Modules are automatically linked through reference variables:

```hcl
# CloudFront references ALB and WAF
cloudfront_spec = {
  web-cf = {
    alb_origin = "web-alb"        # Links to ALB
    waf_key    = "cloudfront-waf" # Links to WAF
  }
}
```

## 🛡️ Security Features

- **Multi-layer Protection**: WAF → CloudFront → Private ALB → EC2
- **Attack Prevention**: SQL injection, XSS, bot protection, rate limiting
- **Geographic Blocking**: Block high-risk countries
- **SSL Termination**: HTTPS at CloudFront edge
- **Private Backend**: No direct internet access to ALB/EC2

## 📚 Documentation

- **[Infrastructure Setup Guide](docs/infra_setup.md)** - Detailed setup and configuration
- **[Architecture Guide](docs/architecture.md)** - Technical architecture details
- **[GitHub Actions Setup](docs/github_actions_setup.md)** - CI/CD pipeline configuration
- **[Module Linking Architecture](docs/module_linking_architecture.md)** - How modules connect
- **[Troubleshooting Guide](docs/troubleshooting.md)** - Common issues and solutions
- **[Shared Services Backend Setup](docs/shared_services_backend_setup.md)** - Backend configuration

## 🚀 Common Tasks

### Scale Resources
```hcl
# Add more instances in tfvars
ec2_spec = {
  "web-server-1" = { instance_type = "t3.small" },
  "web-server-2" = { instance_type = "t3.small" },  # New instance
  "web-server-3" = { instance_type = "t3.small" }   # New instance
}
```

### Test Security
```bash
# Test WAF protection
./scripts/validate-cloudfront.sh dev

# Test specific domain
./scripts/validate-cloudfront.sh dev d1234567890.cloudfront.net
```

### Deploy to Different Environments
```bash
# Staging
terraform workspace select staging || terraform workspace new staging
terraform apply -var-file=tfvars/stg-terraform.tfvars

# Production
terraform workspace select production || terraform workspace new production
terraform apply -var-file=tfvars/prod-terraform.tfvars
```

## 🔍 Troubleshooting

### Common Issues
- **504 Gateway Timeout**: Check ALB target health and CloudFront origin configuration
- **WAF Blocking Legitimate Traffic**: Review WAF logs and adjust rate limits
- **Module Not Found**: Verify module source paths and access permissions

### Useful Commands
```bash
# Check infrastructure status
terraform show

# View outputs
terraform output

# Check target health
aws elbv2 describe-target-health --target-group-arn YOUR_ARN
```

## 🤝 Contributing

1. Configure your environment-specific tfvars files
2. Test in development first
3. Create PRs for staging/production deployments
4. Follow the GitOps workflow for promotions

---

**Ready to deploy?** Start with the [Infrastructure Setup Guide](docs/infra_setup.md) for detailed instructions!