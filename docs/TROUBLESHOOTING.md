# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the Terraform Infrastructure Orchestrator.

## 🚨 Common Issues and Solutions

### 1. Terraform Deployment Issues

#### Issue: Authentication Errors
```
Error: error configuring Terraform AWS Provider: no valid credential sources for Terraform AWS Provider found
```

**Solution:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Configure AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

#### Issue: Resource Already Exists
```
Error: resource already exists
```

**Solution:**
```bash
# Import existing resource
terraform import aws_instance.example i-1234567890abcdef0

# Or delete the existing resource manually
```

#### Issue: VPC/Subnet Not Found
```
Error: VPC not found
```

**Solution:**
1. Verify VPC name in terraform.tfvars matches actual VPC name
2. Check AWS region is correct
3. Ensure VPC exists in the specified region
```bash
# List VPCs
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]'

# List subnets
aws ec2 describe-subnets --query 'Subnets[*].[SubnetId,Tags[?Key==`Name`].Value|[0]]'
```

### 2. ALB Health Check Failures

#### Issue: Targets Showing as Unhealthy
```
Target health check failed
```

**Diagnosis Steps:**
1. **Check ALB Target Group Health**
   ```bash
   # Get target group ARN from Terraform output
   terraform output alb_details
   
   # Check target health
   aws elbv2 describe-target-health --target-group-arn <target-group-arn>
   ```

2. **Verify Health Endpoint**
   ```bash
   # Test health endpoint directly on instance
   curl http://instance-private-ip/health
   
   # For Windows
   curl http://instance-private-ip/health.txt
   ```

3. **Check Security Groups**
   ```bash
   # Verify ALB can reach instances on port 80
   aws ec2 describe-security-groups --group-ids <security-group-id>
   ```

**Common Solutions:**

**Linux Health Check Issues:**
```bash
# SSH to instance and check
sudo systemctl status httpd
sudo tail -f /var/log/httpd/error_log
ls -la /var/www/html/health
curl localhost/health
```

**Windows Health Check Issues:**
```powershell
# RDP to instance and check
Get-Service W3SVC
Get-Content C:\inetpub\wwwroot\health
Invoke-WebRequest http://localhost/health.txt
```

### 3. Instance Launch Failures

#### Issue: Instance Fails to Launch
```
Error: instance failed to launch
```

**Common Causes and Solutions:**

1. **AMI Not Available**
   ```bash
   # Check AMI availability
   aws ec2 describe-images --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" --owners amazon
   ```

2. **Key Pair Not Found**
   ```bash
   # List key pairs
   aws ec2 describe-key-pairs
   
   # Create new key pair if needed
   aws ec2 create-key-pair --key-name your-key-name --query 'KeyMaterial' --output text > your-key-name.pem
   ```

3. **Insufficient Capacity**
   - Try different instance type
   - Try different availability zone
   - Use spot instances if appropriate

### 4. Userdata Script Failures

#### Issue: Web Server Not Starting

**Linux Debugging:**
```bash
# SSH to instance
ssh -i your-key.pem ec2-user@instance-ip

# Check userdata execution
sudo tail -f /var/log/cloud-init-output.log
sudo cat /var/log/userdata.log

# Check Apache status
sudo systemctl status httpd
sudo journalctl -u httpd

# Check if health endpoint exists
ls -la /var/www/html/
curl localhost/health
```

**Windows Debugging:**
```powershell
# RDP to instance
# Check userdata logs
Get-Content C:\UserDataLogs\userdata.log
Get-Content C:\setup-complete.log
Get-Content C:\setup-error.log

# Check IIS status
Get-Service W3SVC
Get-WindowsFeature -Name IIS-*

# Check health endpoint
Test-Path C:\inetpub\wwwroot\health
Invoke-WebRequest http://localhost/health.txt
```

### 5. Network Connectivity Issues

#### Issue: Cannot Access Web Interface

**Diagnosis Steps:**

1. **Check ALB Status**
   ```bash
   # Get ALB DNS name
   terraform output linux_alb_endpoint
   
   # Test ALB connectivity
   curl -I http://your-alb-dns-name
   nslookup your-alb-dns-name
   ```

2. **Check Security Groups**
   ```bash
   # Verify ALB security group allows inbound HTTP/HTTPS
   aws ec2 describe-security-groups --filters "Name=group-name,Values=*alb*"
   
   # Verify instance security group allows inbound from ALB
   aws ec2 describe-security-groups --filters "Name=group-name,Values=*instance*"
   ```

3. **Check Route Tables**
   ```bash
   # Verify routing configuration
   aws ec2 describe-route-tables
   ```

**Common Solutions:**

1. **Update Security Groups**
   ```hcl
   # In terraform configuration
   ingress_rules = [
     {
       from_port   = 80
       to_port     = 80
       protocol    = "tcp"
       cidr_blocks = ["0.0.0.0/0"]  # For ALB
       description = "HTTP from ALB"
     }
   ]
   ```

2. **Check NACLs**
   ```bash
   # Verify Network ACLs aren't blocking traffic
   aws ec2 describe-network-acls
   ```

### 6. SSL/HTTPS Issues

#### Issue: HTTPS Not Working

**Solutions:**

1. **Add SSL Certificate**
   ```hcl
   # In ALB configuration
   https_enabled = true
   certificate_arn = "arn:aws:acm:region:account:certificate/cert-id"
   ```

2. **Update Security Groups**
   ```hcl
   # Allow HTTPS traffic
   {
     from_port   = 443
     to_port     = 443
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
     description = "HTTPS access"
   }
   ```

### 7. Performance Issues

#### Issue: Slow Response Times

**Diagnosis:**
1. **Check ALB Metrics**
   ```bash
   # View ALB metrics in CloudWatch
   aws cloudwatch get-metric-statistics \
     --namespace AWS/ApplicationELB \
     --metric-name TargetResponseTime \
     --dimensions Name=LoadBalancer,Value=your-alb-name
   ```

2. **Check Instance Metrics**
   ```bash
   # View EC2 metrics
   aws cloudwatch get-metric-statistics \
     --namespace AWS/EC2 \
     --metric-name CPUUtilization \
     --dimensions Name=InstanceId,Value=i-1234567890abcdef0
   ```

**Solutions:**
1. **Scale Up Instance Types**
2. **Add More Instances**
3. **Enable Caching**
4. **Optimize Application Code**

### 8. State File Issues

#### Issue: State File Corruption
```
Error: state file appears to be corrupted
```

**Solutions:**
```bash
# Restore from backup
cp terraform.tfstate.backup terraform.tfstate

# Or recreate state by importing resources
terraform import aws_instance.example i-1234567890abcdef0
```

#### Issue: State Lock
```
Error: state is locked
```

**Solutions:**
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>

# Or wait for lock to expire
# Or check if another terraform process is running
```

## 🔍 Diagnostic Commands

### Terraform Diagnostics
```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply

# Validate configuration
terraform validate

# Check state
terraform state list
terraform state show <resource>

# Refresh state
terraform refresh
```

### AWS Diagnostics
```bash
# Check AWS connectivity
aws sts get-caller-identity

# List resources
aws ec2 describe-instances
aws elbv2 describe-load-balancers
aws elbv2 describe-target-groups

# Check logs
aws logs describe-log-groups
aws logs get-log-events --log-group-name <group-name>
```

### Instance Diagnostics

**Linux:**
```bash
# System status
systemctl status httpd
systemctl status amazon-ssm-agent
df -h
free -m
top

# Network
netstat -tlnp
iptables -L
curl -I localhost

# Logs
tail -f /var/log/messages
tail -f /var/log/httpd/error_log
journalctl -f
```

**Windows:**
```powershell
# System status
Get-Service W3SVC
Get-Service AmazonSSMAgent
Get-WmiObject -Class Win32_LogicalDisk
Get-WmiObject -Class Win32_OperatingSystem

# Network
netstat -an
Get-NetFirewallRule
Test-NetConnection localhost -Port 80

# Logs
Get-EventLog -LogName System -Newest 10
Get-EventLog -LogName Application -Newest 10
Get-Content C:\inetpub\logs\LogFiles\W3SVC1\*.log | Select-Object -Last 10
```

## 📞 Getting Help

### Log Collection

Before seeking help, collect these logs:

**Terraform Logs:**
```bash
# Enable logging and save output
export TF_LOG=DEBUG
terraform apply 2>&1 | tee terraform-debug.log
```

**Instance Logs:**
```bash
# Linux
sudo tar -czf instance-logs.tar.gz /var/log/
scp instance-logs.tar.gz local-machine:

# Windows
Compress-Archive -Path C:\UserDataLogs\* -DestinationPath instance-logs.zip
```

### Information to Provide

When seeking help, include:
1. **Environment**: dev/staging/prod
2. **Terraform Version**: `terraform version`
3. **AWS Region**: Where resources are deployed
4. **Error Messages**: Complete error output
5. **Configuration**: Relevant terraform.tfvars (sanitized)
6. **Logs**: Terraform and instance logs
7. **Timeline**: When the issue started
8. **Changes**: Recent changes made

### Support Channels

1. **Documentation**: Check README files and docs/
2. **Issues**: Create GitHub issue with logs and details
3. **Community**: Stack Overflow with terraform and aws tags
4. **AWS Support**: For AWS-specific issues

## 🛠️ Prevention Tips

### Best Practices

1. **Version Control**: Always commit changes before applying
2. **Backups**: Regular state file backups
3. **Testing**: Test in dev before staging/prod
4. **Monitoring**: Set up CloudWatch alarms
5. **Documentation**: Keep configuration documented
6. **Validation**: Use `terraform validate` and `terraform plan`

### Regular Maintenance

1. **Update Terraform**: Keep Terraform version current
2. **Update Modules**: Update external modules regularly
3. **Security Patches**: Keep instances updated
4. **Log Rotation**: Prevent log files from filling disk
5. **State Cleanup**: Remove unused resources from state

Remember: When in doubt, check the logs first! Most issues can be diagnosed by examining the appropriate log files.