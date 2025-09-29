# User Data Scripts

This directory contains server initialization scripts that are executed when EC2 instances are launched.

## Files

- **`userdata-linux.sh`** - Linux server initialization script (Amazon Linux, Ubuntu, etc.)
- **`userdata-windows.ps1`** - Windows server initialization script (Windows Server 2019/2022)

## Usage

These scripts are automatically selected by the Terraform configuration based on the `os_type` parameter in your tfvars files:

```hcl
# Linux instance
ec2_spec = {
  "web-server" = {
    os_type = "linux"        # Uses userdata-linux.sh
    ami_name = "amzn2-ami-hvm-*-x86_64-gp2"
    # ... other config
  }
}

# Windows instance  
ec2_spec = {
  "web-server" = {
    os_type = "windows"      # Uses userdata-windows.ps1
    ami_name = "Windows_Server-2022-English-Full-Base-*"
    # ... other config
  }
}
```

## Template Variables

Both scripts receive the following variables from Terraform:

- `${environment}` - Environment name (dev, staging, prod)
- `${hostname}` - Instance name/hostname
- `${os_type}` - Operating system type

## What the Scripts Do

### Linux Script (`userdata-linux.sh`)
- Installs and configures Apache web server
- Sets up ALB health check endpoints
- Configures EBS volume mounting
- Creates monitoring and logging
- Sets up security headers and compression

### Windows Script (`userdata-windows.ps1`)
- Installs and configures IIS web server
- Sets up ALB health check endpoints
- Formats and mounts additional disks
- Creates monitoring tasks
- Configures firewall rules

## Customization

You can modify these scripts to:
- Install additional software
- Configure application-specific settings
- Set up monitoring agents
- Configure security tools
- Add custom initialization logic

## Best Practices

- Keep scripts idempotent (safe to run multiple times)
- Add proper error handling and logging
- Test scripts thoroughly before deployment
- Use environment variables for configuration
- Keep sensitive data in AWS Systems Manager Parameter Store or Secrets Manager