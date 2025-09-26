# Shared Services Backend Setup Guide

This guide explains how to set up the Terraform backend in a dedicated shared services account for centralized state management across all environments.

## Architecture Benefits

### **Centralized State Management**
- Single S3 bucket in shared services account
- Cross-account access from environment accounts
- Centralized backup and monitoring
- Reduced AWS costs

### **Security & Governance**
- Dedicated account for infrastructure state
- Controlled access via IAM roles
- Audit trail for all state changes
- Separation of concerns

## Prerequisites

### **1. AWS Account Structure**
```
Organization Root
├── Shared Services Account (111111111111)
│   ├── S3 Bucket: terraform-state-central-multi-env
│   └── DynamoDB Table: terraform-state-locks-common
├── Dev Account (221106935066)
├── Staging Account (137617557860)
└── Production Account (333333333333)
```

### **2. Required IAM Roles**
Each account needs `OrganizationAccountAccessRole` that allows:
- Shared Services Account: Full access to S3 bucket and DynamoDB
- Environment Accounts: Cross-account access to shared backend

### **3. AWS CLI Configuration**
Your current AWS credentials should have permission to assume roles in all accounts.

## Setup Steps

### **Step 1: Update Account Configuration**

Edit `config/aws-accounts.json` with your actual account IDs:

```json
{
  "shared_services": {
    "account_id": "111111111111",
    "role_name": "OrganizationAccountAccessRole",
    "description": "Shared services account for centralized backend resources"
  },
  "dev": {
    "account_id": "221106935066",
    "role_name": "OrganizationAccountAccessRole"
  },
  "staging": {
    "account_id": "137617557860",
    "role_name": "OrganizationAccountAccessRole"
  },
  "production": {
    "account_id": "333333333333",
    "role_name": "OrganizationAccountAccessRole"
  }
}
```

### **Step 2: Run Backend Setup**

```bash
# Setup backend in shared services account
./scripts/setup-backend-per-account.sh

# Or setup for specific environment
./scripts/setup-backend-per-account.sh 221106935066
```

This will:
1. Assume role in shared services account
2. Create S3 bucket with cross-account policy
3. Create DynamoDB table for state locking
4. Generate common backend configuration
5. Create workspaces for each environment

### **Step 3: Verify Setup**

```bash
# Check backend configuration
cat shared/backend-common.hcl

# Initialize and test
terraform init -backend-config=shared/backend-common.hcl
terraform workspace list
```

## Cross-Account Access Policy

The setup automatically creates this S3 bucket policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCrossAccountAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::111111111111:root",
          "arn:aws:iam::221106935066:role/OrganizationAccountAccessRole",
          "arn:aws:iam::137617557860:role/OrganizationAccountAccessRole",
          "arn:aws:iam::333333333333:role/OrganizationAccountAccessRole"
        ]
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-central-multi-env",
        "arn:aws:s3:::terraform-state-central-multi-env/*"
      ]
    }
  ]
}
```

## Usage

### **Environment Deployment**

```bash
# Initialize with shared backend
terraform init -backend-config=shared/backend-common.hcl

# Select environment workspace
terraform workspace select dev

# Deploy to dev account
terraform apply -var-file=tfvars/dev-terraform.tfvars
```

### **State File Locations**

State files are stored in the shared services account:
- Dev: `s3://terraform-state-central-multi-env/environments/dev/terraform.tfstate`
- Staging: `s3://terraform-state-central-multi-env/environments/staging/terraform.tfstate`
- Production: `s3://terraform-state-central-multi-env/environments/production/terraform.tfstate`

## Troubleshooting

### **Access Denied Errors**

1. **Check Role Assumption**:
   ```bash
   aws sts assume-role \
     --role-arn arn:aws:iam::111111111111:role/OrganizationAccountAccessRole \
     --role-session-name test-session
   ```

2. **Verify Bucket Policy**:
   ```bash
   aws s3api get-bucket-policy --bucket terraform-state-central-multi-env
   ```

3. **Check DynamoDB Permissions**:
   ```bash
   aws dynamodb describe-table --table-name terraform-state-locks-common
   ```

### **State Lock Issues**

```bash
# Force unlock if needed (use carefully)
terraform force-unlock <lock-id>

# Check lock status
aws dynamodb scan --table-name terraform-state-locks-common
```

### **Re-run Setup**

The setup script is idempotent and can be re-run safely:

```bash
# Update bucket policy with new accounts
./scripts/setup-backend-per-account.sh
```

## Security Best Practices

### **1. Least Privilege Access**
- Environment accounts only access their own state files
- Shared services account has full backend management access
- Regular audit of cross-account permissions

### **2. State File Encryption**
- S3 bucket encryption enabled (AES256)
- DynamoDB encryption at rest enabled
- Versioning enabled for state history

### **3. Monitoring & Auditing**
- CloudTrail logging for all S3 and DynamoDB operations
- S3 access logging for detailed audit trail
- Regular backup of state files

### **4. Access Control**
```bash
# Restrict access to shared services account
# Only infrastructure team should have direct access
# Environment teams access via CI/CD pipelines
```

## Cost Optimization

### **Shared Resources**
- Single S3 bucket instead of per-environment buckets
- Single DynamoDB table for all environments
- Reduced data transfer costs with centralized location

### **Lifecycle Management**
```bash
# Configure S3 lifecycle rules for old state versions
aws s3api put-bucket-lifecycle-configuration \
  --bucket terraform-state-central-multi-env \
  --lifecycle-configuration file://lifecycle.json
```

## Migration from Per-Environment Backends

If migrating from existing per-environment backends:

```bash
# 1. Backup existing state
terraform state pull > backup-dev.tfstate

# 2. Setup new shared backend
./scripts/setup-backend-per-account.sh

# 3. Initialize with new backend
terraform init -backend-config=shared/backend-common.hcl

# 4. Select workspace
terraform workspace select dev

# 5. Push existing state
terraform state push backup-dev.tfstate
```

This setup provides a robust, secure, and cost-effective backend solution for multi-account Terraform deployments.