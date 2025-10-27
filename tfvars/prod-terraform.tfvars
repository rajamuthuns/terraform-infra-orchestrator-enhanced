# Production Environment Configuration Values
# These values are specific to the production environment

# Project configuration
project_name = "terraform-infra-orchestrator"

# AWS configuration
account_id  = "PRODUCTION_ACCOUNT_ID"  # Update with your production account ID
aws_region  = "us-east-1"
environment = "prod"

alb_spec = {
  linux-alb = {
    vpc_name             = "prod-mig-target-vpc"
    internal             = true  # Make ALB private (internal)
    http_enabled         = true
    https_enabled        = true  # Enable HTTPS for production
    name                 = "linux-alb"
    health_check_path    = "/health"
    health_check_matcher = "200"
    
    # Security: Only allow CloudFront IP ranges
    allowed_cidr_blocks = [
      "52.84.0.0/15",      # CloudFront IP ranges
      "54.230.0.0/16",     # CloudFront IP ranges
      "54.239.128.0/18",   # CloudFront IP ranges
      "52.82.128.0/23",    # CloudFront IP ranges
      "52.82.134.0/23",    # CloudFront IP ranges
      "54.240.128.0/18",   # CloudFront IP ranges
      "52.124.128.0/17",   # CloudFront IP ranges
      "54.182.0.0/16",     # CloudFront IP ranges
      "54.192.0.0/16"      # CloudFront IP ranges
    ]
  },
  windows-alb = {
    vpc_name             = "prod-mig-target-vpc"
    internal             = true  # Make ALB private (internal)
    http_enabled         = true
    https_enabled        = true  # Enable HTTPS for production
    name                 = "windows-alb"
    health_check_path    = "/health"
    health_check_matcher = "200"
    
    # Security: Only allow CloudFront IP ranges
    allowed_cidr_blocks = [
      "52.84.0.0/15",      # CloudFront IP ranges
      "54.230.0.0/16",     # CloudFront IP ranges
      "54.239.128.0/18",   # CloudFront IP ranges
      "52.82.128.0/23",    # CloudFront IP ranges
      "52.82.134.0/23",    # CloudFront IP ranges
      "54.240.128.0/18",   # CloudFront IP ranges
      "52.124.128.0/17",   # CloudFront IP ranges
      "54.182.0.0/16",     # CloudFront IP ranges
      "54.192.0.0/16"      # CloudFront IP ranges
    ]
  }
}

ec2_spec = {
  # Linux Instances - Production sizing
  "linux-webserver-1" = {
    enable_alb_integration = true
    alb_name               = "linux-alb"
    instance_type          = "t3.medium"  # Larger for production
    vpc_name               = "prod-mig-target-vpc"
    key_name               = "raja-prod"
    os_type                = "linux"
    ami_name               = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size       = 30  # More storage for production

    # Linux-specific security group rules - Secure configuration
    ingress_rules = [
      {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "SSH access from private networks"
      },
      {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "HTTP access from ALB only"
      },
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "HTTPS access from ALB only"
      }
    ]

    additional_ebs_volumes = [
      {
        device_name = "/dev/sdf"
        size        = 100  # Larger storage for production
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "prod-mig-private-subnet-1"

    tags = {
      Application = "WebServer"
      OS          = "Linux"
      Tier        = "Production"
    }
  },

  "linux-webserver-2" = {
    enable_alb_integration = true
    alb_name               = "linux-alb"
    instance_type          = "t3.medium"  # Larger for production
    vpc_name               = "prod-mig-target-vpc"
    key_name               = "raja-prod"
    os_type                = "linux"
    ami_name               = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size       = 30

    # Linux-specific security group rules - Secure configuration
    ingress_rules = [
      {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "SSH access from private networks"
      },
      {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "HTTP access from ALB only"
      },
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "HTTPS access from ALB only"
      }
    ]

    additional_ebs_volumes = [
      {
        device_name = "/dev/sdf"
        size        = 100
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "prod-mig-private-subnet-2"

    tags = {
      Application = "WebServer"
      OS          = "Linux"
      Tier        = "Production"
    }
  },

  "linux-appserver" = {
    instance_type    = "t3.large"  # Larger for production
    vpc_name         = "prod-mig-target-vpc"
    key_name         = "raja-prod"
    os_type          = "linux"
    ami_name         = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size = 50  # More storage for production

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
        size        = 200  # Larger storage for production
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "prod-mig-private-subnet-1"

    tags = {
      Application = "AppServer"
      OS          = "Ubuntu"
      Tier        = "Production"
    }
  },

  # Windows Instances - Production sizing
  "windows-webserver-1" = {
    enable_alb_integration = true
    alb_name               = "windows-alb"
    instance_type          = "t3.large"  # Larger for production Windows
    vpc_name               = "prod-mig-target-vpc"
    key_name               = "raja-prod"
    os_type                = "windows"
    ami_name               = "Windows_Server-2022-English-Full-Base-*"

    root_volume_size = 80  # More space for production Windows

    # Windows-specific security group rules - Secure configuration
    ingress_rules = [
      {
        from_port   = 3389
        to_port     = 3389
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "RDP access from private networks"
      },
      {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "HTTP access from ALB only"
      },
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "HTTPS access from ALB only"
      }
    ]

    additional_ebs_volumes = [
      {
        device_name = "/dev/sdf" # Windows will see this as D: drive
        size        = 200  # Larger storage for production
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "prod-mig-private-subnet-1"

    tags = {
      Application = "WebServer"
      OS          = "Windows2022"
      Tier        = "Production"
    }
  },

  "windows-webserver-2" = {
    enable_alb_integration = true
    alb_name               = "windows-alb"
    instance_type          = "t3.large"  # Larger for production Windows
    vpc_name               = "prod-mig-target-vpc"
    key_name               = "raja-prod"
    os_type                = "windows"
    ami_name               = "Windows_Server-2022-English-Full-Base-*"

    root_volume_size = 80

    # Windows-specific security group rules - Secure configuration
    ingress_rules = [
      {
        from_port   = 3389
        to_port     = 3389
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "RDP access from private networks"
      },
      {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "HTTP access from ALB only"
      },
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "HTTPS access from ALB only"
      }
    ]

    additional_ebs_volumes = [
      {
        device_name = "/dev/sdf" # Windows will see this as D: drive
        size        = 200
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "prod-mig-private-subnet-2"

    tags = {
      Application = "WebServer"
      OS          = "Windows2022"
      Tier        = "Production"
    }
  }
}

# CloudFront Distribution Specifications
cloudfront_spec = {
  linux-cf = {
    distribution_name     = "linux-app-distribution"
    alb_origin            = "linux-alb" # References the ALB module key
    waf_key               = "cloudfront-waf" # References the WAF module key
    price_class           = "PriceClass_All"  # All edge locations for production
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url     = "https://auth.company.com/login"  # Production SSO

    # Supported CloudFront module parameters
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    tags = {
      Application  = "LinuxWebApp"
      Distribution = "Primary"
      Tier         = "Production"
    }
  },

  windows-cf = {
    distribution_name     = "windows-app-distribution"
    alb_origin            = "windows-alb" # References the ALB module key
    waf_key               = "cloudfront-waf" # References the WAF module key
    price_class           = "PriceClass_All"  # All edge locations for production
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url     = "https://auth.company.com/login"  # Production SSO

    # Supported CloudFront module parameters
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    tags = {
      Application  = "WindowsWebApp"
      Distribution = "Primary"
      Tier         = "Production"
    }
  }
}

# WAF Configuration Specifications - Maximum Security for Production
waf_spec = {
  cloudfront-waf = {
    scope = "CLOUDFRONT"  # For CloudFront distributions

    # Maximum AWS Managed Rules for production
    enable_all_aws_managed_rules = false
    enabled_aws_managed_rules = [
      "common_rule_set",      # Core protection
      "known_bad_inputs",     # Malicious input protection
      "sqli_rule_set",        # SQL injection protection
      "ip_reputation",        # Bad IP blocking
      "linux_rule_set",       # Linux-specific attacks
      "bot_control",          # Bot protection
      "anonymous_ip",         # Anonymous IP blocking
      "atp_rule_set"          # Account takeover protection
    ]

    # Strict production rules
    custom_rules = [
      {
        name                       = "ProductionRateLimit"
        priority                   = 11
        action                     = "block"
        type                       = "rate_based"
        limit                      = 200  # Stricter for production
        aggregate_key_type         = "IP"
        cloudwatch_metrics_enabled = true
        metric_name                = "ProductionRateLimit"
        sampled_requests_enabled   = true
      },
      {
        name                       = "GeoBlockHighRisk"
        priority                   = 12
        action                     = "block"
        type                       = "geo_match"
        country_codes              = ["CN", "RU", "KP", "IR", "SY", "AF", "IQ"]  # Expanded for production
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoBlockHighRisk"
        sampled_requests_enabled   = true
      }
    ]

    # Production IP sets
    ip_sets = {
      trusted_office_ips = {
        ip_address_version = "IPV4"
        addresses = [
          "203.0.113.0/24",    # Corporate HQ (update with real IPs)
          "198.51.100.0/24",   # Branch office (update with real IPs)
          "49.207.205.136/32", # Your current IP
          "10.0.0.0/8"         # Corporate VPN range
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
    log_retention_days = 365  # 1 year retention for production compliance
    
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
      },
      {
        single_header = {
          name = "x-api-key"
        }
      }
    ]

    tags = {
      Purpose     = "ProductionCloudFrontProtection"
      Environment = "Production"
      Security    = "Maximum"
      Compliance  = "SOC2-PCI-Ready"
    }
  }
}