# Environment-Specific Configuration Files

This directory contains environment-specific Terraform variable files (tfvars) that define the configuration for each deployment environment.

## Files

- **`dev-terraform.tfvars`** - Development environment configuration
- **`stg-terraform.tfvars`** - Staging environment configuration  
- **`prod-terraform.tfvars`** - Production environment configuration

## Usage

These files are automatically selected by the deployment workflows based on the target environment:

- **Dev branch** → uses `dev-terraform.tfvars`
- **Staging branch** → uses `stg-terraform.tfvars`
- **Production branch** → uses `prod-terraform.tfvars`

## Manual Deployment

When deploying manually, specify the appropriate tfvars file:

```bash
# Development
terraform plan -var-file=tfvars/dev-terraform.tfvars
terraform apply -var-file=tfvars/dev-terraform.tfvars

# Staging
terraform plan -var-file=tfvars/stg-terraform.tfvars
terraform apply -var-file=tfvars/stg-terraform.tfvars

# Production
terraform plan -var-file=tfvars/prod-terraform.tfvars
terraform apply -var-file=tfvars/prod-terraform.tfvars
```

## Using the Deployment Script

```bash
# Plan changes
./deploy.sh dev plan
./deploy.sh staging plan
./deploy.sh production plan

# Apply changes
./deploy.sh dev apply
./deploy.sh staging apply
./deploy.sh production apply
```

## Using Makefile

```bash
# Quick deployment
make dev      # Deploy to development
make staging  # Deploy to staging
make prod     # Deploy to production

# Individual steps
make plan ENV=dev
make apply ENV=staging
make destroy ENV=production
```

## Configuration Structure

Each tfvars file should contain:

- **Project configuration** - Basic project settings
- **AWS configuration** - Account ID, region, environment name
- **Module specifications** - Configuration for each module (EC2, ALB, etc.)

## Environment Differences

- **Development** - Small, cost-effective resources for testing
- **Staging** - Production-like resources for final testing
- **Production** - Full-scale, highly available resources with security hardening

## Security Notes

- Never commit sensitive values like passwords or API keys
- Use AWS Secrets Manager or Parameter Store for sensitive configuration
- Production configurations should have stricter security settings
- Always review changes before applying to production