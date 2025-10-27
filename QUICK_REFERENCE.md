# 🚀 Quick Reference Guide

## 📋 **Essential Commands**

### **Deployment**
```bash
# Development
terraform apply -var-file=tfvars/dev-terraform.tfvars

# Staging  
terraform apply -var-file=tfvars/stg-terraform.tfvars

# Production
terraform apply -var-file=tfvars/prod-terraform.tfvars
```

### **Get Endpoints**
```bash
terraform output cloudfront_endpoints
terraform output alb_endpoints
terraform output architecture_flow
```

### **Testing**
```bash
# Test CloudFront
curl -v https://your-cloudfront-domain.cloudfront.net

# Test WAF (should be blocked)
curl -v "https://your-cloudfront-domain.cloudfront.net/?id=1%27%20OR%20%271%27=%271"

# Test rate limiting
for i in {1..350}; do curl -s https://your-cloudfront-domain.cloudfront.net; done
```

### **Monitoring**
```bash
# WAF logs
aws logs filter-log-events --log-group-name "aws-waf-logs-dev" --filter-pattern "BLOCK"

# CloudFront metrics
aws cloudwatch get-metric-statistics --namespace AWS/CloudFront --metric-name Requests
```

## 🏗️ **Architecture**
```
Internet → WAF → CloudFront → Private ALB → EC2
```

## 🛡️ **Security Features**
- ✅ WAF: 7 AWS rules + 2 custom rules
- ✅ CloudFront: Global CDN + PING auth
- ✅ Private ALB: Internal only
- ✅ EC2: Private subnets, encrypted storage

## 📊 **Environment Differences**
| Feature | Dev | Staging | Production |
|---------|-----|---------|------------|
| Instance | t3.small | t3.small | t3.medium+ |
| Rate Limit | 300/5min | 300/5min | 200/5min |
| Redundancy | Single | Single | Multiple |
| Log Retention | 180 days | 180 days | 365 days |

## 🔧 **Troubleshooting**
- **502 Errors**: Check ALB health and security groups
- **WAF Blocks**: Review logs, adjust IP whitelist
- **Auth Issues**: Verify PING server connectivity
- **Performance**: Check cache hit ratio and response times

## 📁 **Key Files**
- `README.md`: Project overview
- `COMPLETE_INFRASTRUCTURE_GUIDE.md`: Comprehensive guide
- `tfvars/*.tfvars`: Environment configurations
- `main.tf`: Infrastructure code
- `outputs.tf`: Resource outputs