# Architecture Guide

This document provides detailed technical architecture information for the Terraform Infrastructure Orchestrator.

## 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Internet                              │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                 Internet Gateway                            │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                  Public Subnets                            │
│  ┌─────────────────┐         ┌─────────────────┐           │
│  │   Linux ALB     │         │  Windows ALB    │           │
│  │  (linux-alb)    │         │ (windows-alb)   │           │
│  └─────────────────┘         └─────────────────┘           │
└─────────────────────┬───────────────┬───────────────────────┘
                      │               │
┌─────────────────────▼───────────────▼───────────────────────┐
│                  Private Subnets                           │
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ Linux Instances │  │Windows Instances│                  │
│  │                 │  │                 │                  │
│  │ • Web Server    │  │ • Web Server    │                  │
│  │ • App Server    │  │ • App Server    │                  │
│  └─────────────────┘  └─────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Component Architecture

### Application Load Balancers (ALB)

#### Linux ALB
- **Purpose**: Routes traffic to Linux-based web servers
- **Listeners**: HTTP (port 80), optional HTTPS (port 443)
- **Target Group**: Linux web servers only
- **Health Check**: `/health` endpoint
- **Naming**: `linux-alb-{environment}`

#### Windows ALB
- **Purpose**: Routes traffic to Windows-based web servers
- **Listeners**: HTTP (port 80), optional HTTPS (port 443)
- **Target Group**: Windows web servers only
- **Health Check**: `/health` endpoint
- **Naming**: `windows-alb-{environment}`

### EC2 Instances

#### Linux Instances

**Web Server (linux-webserver)**
- **OS**: Amazon Linux 2
- **Web Server**: Apache HTTP Server
- **Instance Type**: t3.small (dev), t3.medium+ (prod)
- **ALB Integration**: ✅ Enabled
- **Ports**: 22 (SSH), 80 (HTTP), 443 (HTTPS)
- **Health Endpoint**: `/health` returns "OK"

**App Server (linux-appserver)**
- **OS**: Amazon Linux 2
- **Purpose**: Application processing
- **Instance Type**: t3.medium (dev), t3.large+ (prod)
- **ALB Integration**: ❌ Disabled
- **Ports**: 22 (SSH), 8080 (Application)

#### Windows Instances

**Web Server (windows-webserver)**
- **OS**: Windows Server 2019/2022
- **Web Server**: Microsoft IIS
- **Instance Type**: t3.medium (dev), t3.large+ (prod)
- **ALB Integration**: ✅ Enabled
- **Ports**: 3389 (RDP), 80 (HTTP), 443 (HTTPS)
- **Health Endpoint**: `/health` and `/health.txt` return "OK"

**App Server (windows-appserver)**
- **OS**: Windows Server 2019/2022
- **Purpose**: Application processing
- **Instance Type**: t3.large (dev), t3.xlarge+ (prod)
- **ALB Integration**: ❌ Disabled
- **Ports**: 3389 (RDP), 8080 (App), 5985/5986 (WinRM)

## 🌐 Network Architecture

### VPC Configuration
- **VPC**: Pre-existing VPC (e.g., `dev-mig-target-vpc`)
- **CIDR**: Typically 10.0.0.0/16 or similar
- **DNS**: Enabled for hostname resolution

### Subnet Configuration
- **Public Subnets**: For ALB placement
- **Private Subnets**: For EC2 instances
- **Multi-AZ**: Recommended for high availability

### Security Groups

#### ALB Security Groups
```hcl
# Inbound Rules
HTTP  (80)   - 0.0.0.0/0
HTTPS (443)  - 0.0.0.0/0

# Outbound Rules
All Traffic  - 0.0.0.0/0
```

#### Linux Instance Security Groups
```hcl
# Inbound Rules
SSH   (22)   - 10.0.0.0/8 (VPC CIDR)
HTTP  (80)   - ALB Security Group
HTTPS (443)  - ALB Security Group
App   (8080) - 10.0.0.0/8 (for app servers)

# Outbound Rules
All Traffic  - 0.0.0.0/0
```

#### Windows Instance Security Groups
```hcl
# Inbound Rules
RDP    (3389) - 10.0.0.0/8 (VPC CIDR)
HTTP   (80)   - ALB Security Group
HTTPS  (443)  - ALB Security Group
WinRM  (5985) - 10.0.0.0/8 (for app servers)
WinRM  (5986) - 10.0.0.0/8 (for app servers)
App    (8080) - 10.0.0.0/8 (for app servers)

# Outbound Rules
All Traffic   - 0.0.0.0/0
```

## 🔄 Data Flow

### Web Traffic Flow

1. **User Request** → Internet Gateway
2. **Internet Gateway** → ALB (Public Subnet)
3. **ALB** → Target Group Health Check
4. **ALB** → Healthy EC2 Instance (Private Subnet)
5. **EC2 Instance** → Process Request
6. **EC2 Instance** → Return Response via ALB
7. **ALB** → Return Response to User

### Health Check Flow

1. **ALB** → Periodic health check to `/health`
2. **EC2 Instance** → Return "OK" with HTTP 200
3. **ALB** → Mark target as healthy/unhealthy
4. **ALB** → Route traffic only to healthy targets

## 🏥 Health Check Architecture

### ALB Health Checks
- **Protocol**: HTTP
- **Path**: `/health`
- **Port**: 80
- **Interval**: 30 seconds
- **Timeout**: 5 seconds
- **Healthy Threshold**: 2 consecutive successes
- **Unhealthy Threshold**: 2 consecutive failures

### Instance Health Monitoring
- **Linux**: Cron job every 5 minutes
- **Windows**: Scheduled task every 5 minutes
- **Logging**: Local health check logs
- **Alerting**: Can be integrated with CloudWatch

## 🔒 Security Architecture

### Defense in Depth

1. **Network Level**
   - VPC isolation
   - Private subnets for instances
   - Security groups as virtual firewalls
   - NACLs for additional subnet-level control

2. **Instance Level**
   - OS-level firewalls (iptables, Windows Firewall)
   - Regular security updates via userdata
   - Key-based authentication
   - Principle of least privilege

3. **Application Level**
   - Security headers (X-Frame-Options, etc.)
   - Input validation
   - HTTPS encryption (when configured)
   - Health check endpoint protection

### Access Control

#### SSH/RDP Access
- **Linux**: SSH key-based authentication
- **Windows**: RDP with strong passwords or certificates
- **Bastion Host**: Recommended for production environments
- **VPN**: Alternative secure access method

#### Service Access
- **Web Services**: Through ALB only
- **Application Services**: Internal network only
- **Management**: Restricted to admin networks

## 📊 Monitoring Architecture

### Built-in Monitoring

#### Web Dashboards
- **Homepage**: Server information and status
- **Status Page**: Real-time server health
- **System Info**: Detailed system information
- **Health Endpoint**: ALB health check endpoint

#### Log Files
- **Linux**: `/var/log/userdata.log`, `/var/log/health.log`
- **Windows**: `C:\UserDataLogs\userdata.log`, `C:\health.log`
- **Apache**: `/var/log/httpd/access_log`, `/var/log/httpd/error_log`
- **IIS**: Windows Event Logs, IIS logs

### CloudWatch Integration (Optional)

#### Metrics
- **EC2**: CPU, Memory, Disk, Network
- **ALB**: Request count, latency, error rates
- **Custom**: Application-specific metrics

#### Alarms
- **High CPU**: > 80% for 5 minutes
- **Health Check Failures**: > 2 consecutive failures
- **High Error Rate**: > 5% error rate

## 🔄 Scalability Architecture

### Horizontal Scaling
- **Auto Scaling Groups**: Can be added to scale instances
- **ALB Target Groups**: Automatically distribute load
- **Multi-AZ Deployment**: High availability across zones

### Vertical Scaling
- **Instance Types**: Easy to change via Terraform
- **EBS Volumes**: Can be resized without downtime
- **Memory/CPU**: Upgrade instance families as needed

## 🗂️ File System Architecture

### Linux File System
```
/
├── var/
│   ├── www/html/          # Web content
│   └── log/               # Log files
├── opt/                   # Custom scripts
└── data*/                 # Additional EBS volumes
```

### Windows File System
```
C:\
├── inetpub\wwwroot\       # Web content
├── UserDataLogs\          # Log files
├── Scripts\               # Custom scripts
└── D:\, E:\, F:\          # Additional EBS volumes
```

## 🔧 Configuration Management

### Terraform Modules
- **ALB Module**: External module for load balancer creation
- **EC2 Module**: External module for instance creation
- **Local Configuration**: Environment-specific settings

### Environment Separation
- **Directory Structure**: Separate directories per environment
- **State Files**: Isolated state per environment
- **Variable Files**: Environment-specific terraform.tfvars

### Naming Conventions
- **Resources**: `{resource-type}-{environment}`
- **Tags**: Consistent tagging strategy
- **Outputs**: Descriptive output names

## 🚀 Deployment Architecture

### Infrastructure as Code
- **Terraform**: Primary deployment tool
- **Version Control**: Git-based workflow
- **State Management**: Local or remote state storage

### CI/CD Integration (Future)
- **Pipeline Stages**: Plan → Apply → Test → Deploy
- **Approval Gates**: Manual approval for production
- **Rollback Strategy**: Previous state restoration

## 📈 Performance Architecture

### Load Balancing
- **Algorithm**: Round robin (default)
- **Sticky Sessions**: Disabled (stateless applications)
- **Connection Draining**: Graceful instance removal

### Caching Strategy
- **Static Content**: Can be served by CloudFront
- **Dynamic Content**: Application-level caching
- **Database**: Separate caching layer if needed

### Optimization
- **HTTP Compression**: Enabled on both Apache and IIS
- **Keep-Alive**: Enabled for persistent connections
- **Resource Optimization**: Minified CSS/JS in userdata

This architecture provides a solid foundation for scalable, secure, and maintainable web infrastructure on AWS.