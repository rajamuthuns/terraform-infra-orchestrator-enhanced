# Staging Environment Configuration Values
# These values are specific to the staging environment

# Project configuration
project_name = "terraform-infra-orchestrator"

# AWS configuration
account_id  = "137617557860"
aws_region  = "us-east-1"
environment = "staging"

alb_spec = {
  linux-alb = {
    vpc_name             = "staging-mig-target-vpc"
    http_enabled         = true
    https_enabled        = false
    name                 = "linux-alb"
    health_check_path    = "/health"
    health_check_matcher = "200"
  },
  windows-alb = {
    vpc_name             = "staging-mig-target-vpc"
    http_enabled         = true
    https_enabled        = false
    name                 = "windows-alb"
    health_check_path    = "/health"
    health_check_matcher = "200"
  }
}

ec2_spec = {
  # Linux Instances
  "linux-webserver" = {
    enable_alb_integration = true
    alb_name               = "linux-alb"
    instance_type          = "t3.small"
    vpc_name               = "staging-mig-target-vpc"
    key_name               = "raja-staging"
    os_type                = "linux"
    ami_name               = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size       = 20

    # Linux-specific security group rules - Secure configuration
    ingress_rules = [
      {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "SSH access from private networks"
      }
    ]

    additional_ebs_volumes = [
      {
        device_name = "/dev/sdf"
        size        = 50
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "staging-mig-private-subnet-1"

    tags = {
      Application = "WebServer"
      OS          = "Linux"
    }
  },

  "linux-appserver" = {
    instance_type    = "t3.medium"
    vpc_name         = "staging-mig-target-vpc"
    key_name         = "raja-staging"
    os_type          = "linux"
    ami_name         = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size = 30

    ingress_rules = [
      {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "SSH access from private networks"
      },
      {
        from_port   = 8080
        to_port     = 8080
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "Application port from VPC"
      }
    ]

    additional_ebs_volumes = [
      {
        device_name = "/dev/sdg"
        size        = 100
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "staging-mig-private-subnet-2"

    tags = {
      Application = "AppServer"
      OS          = "Ubuntu"
    }
  },

  # Windows Instances
  "windows-webserver" = {
    enable_alb_integration = true
    alb_name               = "windows-alb"
    instance_type          = "t3.medium" # Windows typically needs more resources
    vpc_name               = "staging-mig-target-vpc"
    key_name               = "raja-staging"
    os_type                = "windows"
    ami_name               = "Windows_Server-2022-English-Full-Base-*"

    root_volume_size = 50 # Windows needs more space

    # Windows-specific security group rules - Secure configuration
    ingress_rules = [
      {
        from_port   = 3389
        to_port     = 3389
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "RDP access from private networks"
      }
    ]

    additional_ebs_volumes = [
      {
        device_name = "/dev/sdf" # Windows will see this as D: drive
        size        = 100
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "staging-mig-private-subnet-1"

    tags = {
      Application = "WebServer"
      OS          = "Windows2022"
    }
  },

  "windows-appserver" = {
    instance_type    = "t3.large"
    vpc_name         = "staging-mig-target-vpc"
    key_name         = "raja-staging"
    os_type          = "windows"
    ami_name         = "Windows_Server-2019-English-Full-Base-*"
    root_volume_size = 80

    ingress_rules = [
      {
        from_port   = 3389
        to_port     = 3389
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "RDP access from private networks"
      },
      {
        from_port   = 8080
        to_port     = 8080
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "Application port from VPC"
      },
      {
        from_port   = 5985
        to_port     = 5985
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "WinRM HTTP from VPC"
      },
      {
        from_port   = 5986
        to_port     = 5986
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "WinRM HTTPS from VPC"
      }
    ]

    additional_ebs_volumes = [
      {
        device_name = "/dev/sdg" # Windows will see this as E: drive
        size        = 200
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "staging-mig-private-subnet-2"

    tags = {
      Application = "AppServer"
      OS          = "Windows2019"
    }
  }
}

# CloudFront Distribution Specifications
cloudfront_spec = {
  linux-cf = {
    distribution_name     = "linux-app-distribution"
    alb_origin            = "linux-alb" # References the ALB module key
    waf_key               = "cloudfront-waf" # References the WAF module key
    price_class           = "PriceClass_100"
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url     = "https://auth.staging.example.com/login"

    # Supported CloudFront module parameters
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    tags = {
      Application  = "LinuxWebApp"
      Distribution = "Primary"
    }
  },

  windows-cf = {
    distribution_name     = "windows-app-distribution"
    alb_origin            = "windows-alb" # References the ALB module key
    waf_key               = "cloudfront-waf" # References the WAF module key
    price_class           = "PriceClass_100"
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url     = "https://auth.staging.example.com/login"

    # Supported CloudFront module parameters
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    tags = {
      Application  = "WindowsWebApp"
      Distribution = "Primary"
    }
  }
}

# WAF Configuration Specifications - Production-Grade Security
waf_spec = {
  cloudfront-waf = {
    scope = "CLOUDFRONT"  # For CloudFront distributions

    # Comprehensive AWS Managed Rules for maximum protection
    enable_all_aws_managed_rules = false
    enabled_aws_managed_rules = [
      "common_rule_set",      # Core protection
      "known_bad_inputs",     # Malicious input protection
      "sqli_rule_set",        # SQL injection protection
      "ip_reputation",        # Bad IP blocking
      "linux_rule_set",       # Linux-specific attacks
      "bot_control",          # Bot protection
      "anonymous_ip"          # Anonymous IP blocking
    ]

    # Production-grade custom rules with layered security
    custom_rules = [
      {
        name                       = "AggressiveRateLimit"
        priority                   = 11
        action                     = "block"
        type                       = "rate_based"
        limit                      = 300  # 300 requests per 5 minutes
        aggregate_key_type         = "IP"
        cloudwatch_metrics_enabled = true
        metric_name                = "AggressiveRateLimit"
        sampled_requests_enabled   = true
      },
      {
        name                       = "GeoBlockHighRisk"
        priority                   = 12
        action                     = "block"
        type                       = "geo_match"
        country_codes              = ["CN", "RU", "KP", "IR", "SY"]  # Expanded high-risk countries
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoBlockHighRisk"
        sampled_requests_enabled   = true
      }
    ]

    # Enhanced IP sets for comprehensive security
    ip_sets = {
      trusted_office_ips = {
        ip_address_version = "IPV4"
        addresses = [
          "203.0.113.0/24",    # Corporate office (update with your real IPs)
          "198.51.100.0/24",   # Branch office (update with your real IPs)
          "49.207.205.136/32"  # Your current IP
        ]
      },
      blocked_malicious_ips = {
        ip_address_version = "IPV4"
        addresses = [
          "192.0.2.0/24"       # Known malicious range
        ]
      }
    }

    # Production logging configuration
    enable_logging = true
    log_retention_days = 180  # 6 months retention for compliance
    
    # Privacy-compliant redacted fields
    redacted_fields = [
      {
        single_header = {
          name = "authorization"
        }
      },
      {
        single_header = {
          name = "cookie"
        }
      }
    ]

    tags = {
      Purpose     = "ProductionCloudFrontProtection"
      Environment = "Staging"
      Security    = "Maximum"
    }
  }
}