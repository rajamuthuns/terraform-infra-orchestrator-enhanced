# GitHub Actions Setup Guide

This guide walks you through setting up the Terraform Infrastructure Orchestrator with GitHub Actions for automated CI/CD deployment.

## Overview

The GitHub Actions workflow provides:
- Branch-based environment deployment (dev, staging, production)
- Terraform validation, planning, and deployment
- Workspace isolation for each environment
- Manual workflow dispatch with configurable options
- Secure AWS credential management with cross-account role assumption
- Production approval gates

## Prerequisites

1. **GitHub Repository**: Repository with Actions enabled
2. **AWS Accounts**: Separate AWS accounts for each environment (recommended)
3. **AWS Credentials**: Access to assume roles across accounts
4. **Terraform**: Version 1.6.0 or compatible

## Setup Steps

### 1. Configure GitHub Secrets

Navigate to your repository → Settings → Secrets and variables → Actions

Add the following repository secrets:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `PRIVATE_REPO_TOKEN` | GitHub token with repo access | `ghp_xxxxxxxxxxxx` |
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_SESSION_TOKEN` | AWS Session Token (if using temporary credentials) | `IQoJb3JpZ2luX2VjE...` |

### 2. Configure AWS Account Mapping

Update `config/aws-accounts.json` with your AWS account IDs:

```json
{
  "dev": {
    "account_id": "123456789012"
  },
  "staging": {
    "account_id": "234567890123"
  },
  "production": {
    "account_id": "345678901234"
  }
}
```

### 3. Setup Cross-Account IAM Roles

Ensure each target account has the `OrganizationAccountAccessRole` that can be assumed by your source credentials.

Example trust policy for the role:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::SOURCE_ACCOUNT_ID:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### 4. Initialize Backend Infrastructure

Run the backend setup script to create S3 buckets and DynamoDB tables:

```bash
# Setup for specific account
./scripts/setup-backend-per-account.sh 123456789012

# Setup for all environments
./scripts/setup-backend-per-account.sh
```

This creates:
- S3 buckets for Terraform state storage
- DynamoDB tables for state locking
- Backend configuration files in `shared/backend-*.hcl`

### 5. Create GitOps Branches

Create the required branches manually:

```bash
# Create and push dev branch
git checkout -b dev
git push -u origin dev

# Create and push staging branch  
git checkout -b staging
git push -u origin staging

# Create and push production branch
git checkout -b production
git push -u origin production

# Return to main branch
git checkout main
```

This creates:
- `dev` branch for development
- `staging` branch for staging
- `production` branch for production

## Workflow Structure

### Branch-Based Deployment

| Branch | Environment | Tfvars File | Approval Required |
|--------|-------------|-------------|-------------------|
| `dev` | Development | `tfvars/dev-terraform.tfvars` | ❌ |
| `staging` | Staging | `tfvars/stg-terraform.tfvars` | ✅ |
| `production` | Production | `tfvars/prod-terraform.tfvars` | ✅ + Apply Approval |

### Workflow Jobs

1. **Determine Environment**: Detects environment from branch name
2. **Terraform Plan**: Creates execution plan using appropriate tfvars
3. **Terraform Apply**: Applies changes (with approvals for staging/prod)
4. **Production Apply Approval**: Additional approval gate for production

## Usage Examples

### Development Deployment

```bash
# Switch to dev branch
git checkout dev

# Make changes to infrastructure
nano main.tf
nano tfvars/dev-terraform.tfvars

# Commit and push
git add .
git commit -m "feat: add new infrastructure"
git push origin dev

# Workflow automatically deploys to dev environment
```

### Staging Deployment

```bash
# Create PR from dev to staging
git checkout staging
git merge dev
git push origin staging

# Workflow requires approval before deployment
```

### Production Deployment

```bash
# Create PR from staging to production
git checkout production
git merge staging
git push origin production

# Workflow requires:
# 1. Team approval for PR
# 2. Additional approval for terraform apply
```

### Manual Deployment

1. Go to Actions → "Terraform Infrastructure Deploy"
2. Click "Run workflow"
3. Select environment and action
4. Click "Run workflow"

## Environment Protection

Configure GitHub Environments for deployment protection:

### Development Environment
- **Name**: `dev`
- **Protection**: None (auto-deploy)

### Staging Environment
- **Name**: `staging`
- **Protection**: Required reviewers (1 person)

### Production Environment
- **Name**: `production`
- **Protection**: Required reviewers (2 people)

### Production Apply Approval
- **Name**: `production-apply-approval`
- **Protection**: Required reviewers for terraform apply

## Troubleshooting

### Common Issues

1. **AWS Credentials Error**
   - Verify GitHub secrets are correctly set
   - Check AWS account IDs in `config/aws-accounts.json`
   - Ensure cross-account roles exist and are assumable

2. **Backend Not Found**
   - Run backend setup script: `./scripts/setup-backend-per-account.sh`
   - Check S3 bucket permissions
   - Verify backend configuration files exist in `shared/`

3. **Tfvars File Not Found**
   - Ensure tfvars files exist in `tfvars/` directory
   - Check file naming: `dev-terraform.tfvars`, `stg-terraform.tfvars`, `prod-terraform.tfvars`

4. **Workspace Issues**
   - Workspaces are created automatically
   - Each environment uses its own workspace for isolation

### Debugging Steps

1. **Check Workflow Logs**
   - Go to Actions tab
   - Click on failed workflow run
   - Expand failed job steps

2. **Verify Configuration**
   - Check `config/aws-accounts.json`
   - Verify tfvars files in `tfvars/` directory
   - Confirm backend configurations in `shared/`

3. **Test Locally**
   ```bash
   # Initialize with backend
   terraform init -backend-config=shared/backend-dev.hcl
   
   # Select workspace
   terraform workspace select dev
   
   # Plan with tfvars
   terraform plan -var-file=tfvars/dev-terraform.tfvars
   ```

## Security Considerations

1. **Credential Management**
   - Use temporary credentials when possible
   - Rotate secrets regularly
   - Limit credential scope to minimum required

2. **Cross-Account Access**
   - Use least-privilege IAM policies
   - Monitor cross-account role usage
   - Implement CloudTrail logging

3. **State File Security**
   - Enable S3 bucket encryption
   - Use bucket policies to restrict access
   - Enable versioning and MFA delete

4. **Approval Gates**
   - Production requires team approval
   - Additional approval for terraform apply in production
   - All approvals are logged and auditable

## File Structure

The workflow expects this structure:

```
terraform-infra-orchestrator/
├── main.tf                     # Infrastructure code
├── variables.tf                # Variable definitions
├── outputs.tf                  # Output definitions
├── tfvars/                     # Environment configurations
│   ├── dev-terraform.tfvars    # Dev environment
│   ├── stg-terraform.tfvars    # Staging environment
│   └── prod-terraform.tfvars   # Production environment
├── shared/                     # Backend configurations
│   ├── backend-dev.hcl         # Dev backend
│   ├── backend-staging.hcl     # Staging backend
│   └── backend-prod.hcl        # Production backend
└── config/                     # GitOps configuration
    └── aws-accounts.json       # Account mappings
```

This setup provides a complete GitOps workflow with proper environment isolation and approval gates for safe infrastructure deployment.