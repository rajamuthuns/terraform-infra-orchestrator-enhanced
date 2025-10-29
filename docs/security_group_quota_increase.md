# AWS Security Group Quota Increase Guide

## 🎯 Overview

To use CloudFront prefix lists with ALB security groups, you must increase the AWS security group quota from the default 60 rules to 500 rules per security group.

## ⚠️ Why This Is Required

**CloudFront Prefix List Challenge:**
- **CloudFront Prefix List ID**: `pl-3b927c52`
- **Current IP Ranges**: ~300 CloudFront IP ranges globally
- **Default Security Group Limit**: 60 rules per group
- **Result**: Deployment fails with "Rules per security group limit exceeded"

## 📋 Quota Increase Request Details

### Request Information
- **Service**: Amazon Virtual Private Cloud (Amazon VPC)
- **Quota Name**: Inbound or outbound rules per security group
- **Quota Code**: L-0EA8095F
- **Current Limit**: 60 rules
- **Requested Limit**: 500 rules
- **Justification**: Required for CloudFront prefix list (pl-3b927c52) containing ~300 IP ranges

## 🚀 How to Request Quota Increase

### Method 1: AWS Console (Recommended)

1. **Navigate to Service Quotas:**
   ```
   AWS Console → Service Quotas → Amazon Virtual Private Cloud (Amazon VPC)
   ```

2. **Find the Quota:**
   - Search for: "Inbound or outbound rules per security group"
   - Or filter by quota code: "L-0EA8095F"

3. **Request Increase:**
   - Click "Request quota increase"
   - New quota value: **500**
   - Use case description: "Required for CloudFront prefix list (pl-3b927c52) which contains approximately 300 IP ranges for secure CloudFront-only ALB access in production environment"

### Method 2: AWS CLI

```bash
# Request quota increase via CLI
aws service-quotas request-service-quota-increase \
  --service-code ec2 \
  --quota-code L-0EA8095F \
  --desired-value 500 \
  --region us-east-1

# Check request status
aws service-quotas list-requested-service-quota-change-history \
  --service-code ec2 \
  --region us-east-1
```

### Method 3: AWS Support Case

If Service Quotas doesn't allow the increase, create a support case:

1. **Case Details:**
   - **Service**: Service Quotas
   - **Category**: EC2 Security Groups
   - **Severity**: Normal
   - **Subject**: "Increase Security Group Rules Quota to 500"

2. **Case Description:**
   ```
   Request: Increase "Rules per security group" quota from 60 to 500
   
   Service: Amazon EC2
   Quota Code: L-0EA8095F
   Region: us-east-1 (and other regions as needed)
   
   Business Justification:
   We are implementing a secure CloudFront architecture that requires using 
   AWS managed CloudFront prefix list (pl-3b927c52) in ALB security groups. 
   This prefix list contains approximately 300 IP ranges covering all 
   CloudFront edge locations globally.
   
   The current limit of 60 rules per security group is insufficient to 
   accommodate this prefix list, causing deployment failures. We request 
   an increase to 500 rules to handle current CloudFront IPs plus provide 
   buffer for future expansion.
   
   This is for production infrastructure requiring CloudFront-only access 
   to Application Load Balancers for security compliance.
   ```

## ⏱️ Processing Timeline

- **Service Quotas**: Usually auto-approved or processed within 24-48 hours
- **Support Case**: 1-3 business days depending on support plan
- **Notification**: You'll receive email confirmation when approved

## ✅ Verification

### Check Current Quota
```bash
# Check current quota value
aws service-quotas get-service-quota \
  --service-code ec2 \
  --quota-code L-0EA8095F \
  --region us-east-1

# Expected output after approval:
# "Value": 500.0
```

### Test Deployment
```bash
# After quota increase, test deployment
terraform plan -var-file=tfvars/dev-terraform.tfvars

# Should not show any security group rule limit errors
```

## 🌍 Multi-Region Considerations

If deploying to multiple regions, request quota increases for each region:

```bash
# Request for multiple regions
for region in us-east-1 us-west-2 eu-west-1; do
  aws service-quotas request-service-quota-increase \
    --service-code ec2 \
    --quota-code L-0EA8095F \
    --desired-value 500 \
    --region $region
done
```

## 🔍 Troubleshooting

### Common Issues

1. **"Quota increase not available"**
   - Use AWS Support case method instead
   - Some accounts may require support case for large increases

2. **"Request denied"**
   - Provide more detailed business justification
   - Mention production/compliance requirements
   - Reference specific CloudFront prefix list usage

3. **"Quota increase pending"**
   - Wait for processing (usually 24-48 hours)
   - Check email for updates
   - Follow up via support case if delayed

### Verification Commands

```bash
# Check if CloudFront prefix list exists
aws ec2 describe-managed-prefix-lists \
  --prefix-list-ids pl-3b927c52 \
  --region us-east-1

# Count entries in prefix list
aws ec2 get-managed-prefix-list-entries \
  --prefix-list-id pl-3b927c52 \
  --region us-east-1 \
  --query 'Entries | length(@)'
```

## 📞 Support Information

- **AWS Support**: Available through AWS Console → Support Center
- **Documentation**: [AWS Service Quotas User Guide](https://docs.aws.amazon.com/servicequotas/latest/userguide/)
- **EC2 Quotas**: [Amazon EC2 Service Quotas](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-resource-limits.html)

## 🎯 Success Criteria

After quota increase approval:
- ✅ Security group quota shows 500 rules
- ✅ Terraform deployment succeeds without rule limit errors
- ✅ ALB security groups can use CloudFront prefix list
- ✅ CloudFront traffic reaches ALB successfully
- ✅ Direct ALB access is blocked (non-CloudFront IPs)

---

**Note**: This quota increase is a one-time setup requirement. Once approved, all future deployments in the region will benefit from the increased limit.