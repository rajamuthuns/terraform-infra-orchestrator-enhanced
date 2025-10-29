# Production Environment Configuration Values
# These values are specific to the production environment
# High-availability, performance-optimized, and security-hardened configuration

# Project configuration
project_name = "terraform-infra-orchestrator"

# AWS configuration
account_id  = "221106935066"  # Update with your production account ID
aws_region  = "us-east-1"
environment = "prod"

alb_spec = {
  linux-alb = {
    vpc_name              = "dev-mig-target-vpc"  # Keep same VPC for production
    http_enabled          = true
    https_enabled         = true
    certificate_arn       = "arn:aws:acm:us-east-1:221106935066:certificate/e1ace7b1-f324-4ac6-aff3-7ec67edc8622"
    name                  = "linux-alb"
    health_check_path     = "/health"
    health_check_matcher  = "200"
    target_group_port     = 80
    target_group_protocol = "HTTP"
  },
  windows-alb = {
    vpc_name              = "dev-mig-target-vpc"  # Keep same VPC for production
    http_enabled          = true
    https_enabled         = true
    certificate_arn       = "arn:aws:acm:us-east-1:221106935066:certificate/e1ace7b1-f324-4ac6-aff3-7ec67edc8622"
    name                  = "windows-alb"
    health_check_path     = "/health.txt"
    health_check_matcher  = "200"
    target_group_port     = 80
    target_group_protocol = "HTTP"
  }
}

ec2_spec = {
  # Linux Instances - Production-grade with high availability
  "linux-webserver-1" = {
    enable_alb_integration = true
    alb_name               = "linux-alb"
    instance_type          = "t3.medium"  # Production-grade
    vpc_name               = "dev-mig-target-vpc"
    key_name               = "raja-dev"
    os_type                = "linux"
    ami_name               = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size       = 50  # Production storage

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
        description = "HTTP access from ALB for health checks and traffic"
      },
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "HTTPS access from ALB for health checks and traffic"
      }
    ]

    additional_ebs_volumes = [
      {
        device_name = "/dev/sdf"
        size        = 200  # Production storage
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-1"

    tags = {
      Application = "WebServer"
      OS          = "Linux"
      Environment = "Production"
      Tier        = "Web"
    }
  },

  "linux-webserver-2" = {
    enable_alb_integration = true
    alb_name               = "linux-alb"
    instance_type          = "t3.medium"  # Production-grade
    vpc_name               = "dev-mig-target-vpc"
    key_name               = "raja-dev"
    os_type                = "linux"
    ami_name               = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size       = 50  # Production storage

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
        description = "HTTP access from ALB for health checks and traffic"
      },
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "HTTPS access from ALB for health checks and traffic"
      }
    ]

    additional_ebs_volumes = [
      {
        device_name = "/dev/sdf"
        size        = 200  # Production storage
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-2"  # Different AZ for HA

    tags = {
      Application = "WebServer"
      OS          = "Linux"
      Environment = "Production"
      Tier        = "Web"
    }
  },

  "linux-appserver-1" = {
    instance_type    = "t3.large"  # Production-grade
    vpc_name         = "dev-mig-target-vpc"
    key_name         = "raja-dev"
    os_type          = "linux"
    ami_name         = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size = 100  # Production storage

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
        size        = 500  # Production storage
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-1"

    tags = {
      Application = "AppServer"
      OS          = "Linux"
      Environment = "Production"
      Tier        = "Application"
    }
  },

  "linux-appserver-2" = {
    instance_type    = "t3.large"  # Production-grade
    vpc_name         = "dev-mig-target-vpc"
    key_name         = "raja-dev"
    os_type          = "linux"
    ami_name         = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size = 100  # Production storage

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
        size        = 500  # Production storage
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-2"  # Different AZ for HA

    tags = {
      Application = "AppServer"
      OS          = "Linux"
      Environment = "Production"
      Tier        = "Application"
    }
  },

  # Windows Instances - Production-grade with high availability
  "windows-webserver-1" = {
    enable_alb_integration = true
    alb_name               = "windows-alb"
    instance_type          = "t3.large"  # Production-grade for Windows
    vpc_name               = "dev-mig-target-vpc"
    key_name               = "raja-dev"
    os_type                = "windows"
    ami_name               = "Windows_Server-2022-English-Full-Base-*"

    root_volume_size = 100  # Production storage for Windows

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
        description = "HTTP access from ALB for health checks and traffic"
      },
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "HTTPS access from ALB for health checks and traffic"
      }
    ]

    additional_ebs_volumes = [
      {
        device_name = "/dev/sdf" # Windows will see this as D: drive
        size        = 300  # Production storage
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-1"

    tags = {
      Application = "WebServer"
      OS          = "Windows2022"
      Environment = "Production"
      Tier        = "Web"
    }
  },

  "windows-webserver-2" = {
    enable_alb_integration = true
    alb_name               = "windows-alb"
    instance_type          = "t3.large"  # Production-grade for Windows
    vpc_name               = "dev-mig-target-vpc"
    key_name               = "raja-dev"
    os_type                = "windows"
    ami_name               = "Windows_Server-2022-English-Full-Base-*"

    root_volume_size = 100  # Production storage for Windows

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
        description = "HTTP access from ALB for health checks and traffic"
      },
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
        description = "HTTPS access from ALB for health checks and traffic"
      }
    ]

    additional_ebs_volumes = [
      {
        device_name = "/dev/sdf" # Windows will see this as D: drive
        size        = 300  # Production storage
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-2"  # Different AZ for HA

    tags = {
      Application = "WebServer"
      OS          = "Windows2022"
      Environment = "Production"
      Tier        = "Web"
    }
  },

  "windows-appserver-1" = {
    instance_type    = "t3.xlarge"  # Production-grade for Windows
    vpc_name         = "dev-mig-target-vpc"
    key_name         = "raja-dev"
    os_type          = "windows"
    ami_name         = "Windows_Server-2019-English-Full-Base-*"
    root_volume_size = 150  # Production storage for Windows

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
        size        = 500  # Production storage
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-1"

    tags = {
      Application = "AppServer"
      OS          = "Windows2019"
      Environment = "Production"
      Tier        = "Application"
    }
  },

  "windows-appserver-2" = {
    instance_type    = "t3.xlarge"  # Production-grade for Windows
    vpc_name         = "dev-mig-target-vpc"
    key_name         = "raja-dev"
    os_type          = "windows"
    ami_name         = "Windows_Server-2019-English-Full-Base-*"
    root_volume_size = 150  # Production storage for Windows

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
        size        = 500  # Production storage
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-2"  # Different AZ for HA

    tags = {
      Application = "AppServer"
      OS          = "Windows2019"
      Environment = "Production"
      Tier        = "Application"
    }
  }
}

# CloudFront Distribution Specifications - Production Environment
cloudfront_spec = {
  linux-cf = {
    distribution_name     = "linux-app-distribution-production"
    alb_origin            = "linux-alb" # References the ALB module key
    waf_key               = "cloudfront-waf" # References the WAF module key
    price_class           = "PriceClass_All"  # Global distribution for production
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url     = "https://auth.example.com/login"

    # Supported CloudFront module parameters
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    tags = {
      Application  = "LinuxWebApp"
      Distribution = "Production"
      Environment  = "Production"
      Criticality  = "High"
    }
  },

  windows-cf = {
    distribution_name     = "windows-app-distribution-production"
    alb_origin            = "windows-alb" # References the ALB module key
    waf_key               = "cloudfront-waf" # References the WAF module key
    price_class           = "PriceClass_All"  # Global distribution for production
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url     = "https://auth.example.com/login"

    # Supported CloudFront module parameters
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    tags = {
      Application  = "WindowsWebApp"
      Distribution = "Production"
      Environment  = "Production"
      Criticality  = "High"
    }
  }
}

# WAF Configuration Specifications - Production Environment (Maximum Security)
waf_spec = {
  cloudfront-waf = {
    scope = "CLOUDFRONT"  # For CloudFront distributions

    # Comprehensive AWS Managed Rules for maximum production protection
    enable_all_aws_managed_rules = false
    enabled_aws_managed_rules = [
      "common_rule_set",      # Core protection
      "known_bad_inputs",     # Malicious input protection
      "sqli_rule_set",        # SQL injection protection
      "xss_rule_set",         # Cross-site scripting protection
      "ip_reputation",        # Bad IP blocking
      "linux_rule_set",       # Linux-specific attacks
      "windows_rule_set",     # Windows-specific attacks
      "bot_control",          # Bot protection
      "anonymous_ip",         # Anonymous IP blocking
      "rate_based_rule"       # Rate limiting
    ]

    # Production-grade custom rules with aggressive security
    custom_rules = [
      {
        name                       = "ProductionRateLimit"
        priority                   = 11
        action                     = "block"
        type                       = "rate_based"
        limit                      = 200  # Aggressive rate limiting for production
        aggregate_key_type         = "IP"
        cloudwatch_metrics_enabled = true
        metric_name                = "ProductionRateLimit"
        sampled_requests_enabled   = true
      },
      {
        name                       = "ProductionGeoBlock"
        priority                   = 12
        action                     = "block"
        type                       = "geo_match"
        country_codes              = ["CN", "RU", "KP", "IR", "SY", "CU", "SD"]  # Comprehensive geo-blocking
        cloudwatch_metrics_enabled = true
        metric_name                = "ProductionGeoBlock"
        sampled_requests_enabled   = true
      },
      {
        name                       = "ProductionSuspiciousUserAgent"
        priority                   = 13
        action                     = "block"
        type                       = "string_match"
        match_field               = "user_agent"
        match_pattern             = "bot|crawler|scanner|hack"
        cloudwatch_metrics_enabled = true
        metric_name                = "ProductionSuspiciousUserAgent"
        sampled_requests_enabled   = true
      }
    ]

    # Production IP sets with comprehensive security
    ip_sets = {
      trusted_office_ips = {
        ip_address_version = "IPV4"
        addresses = [
          "203.0.113.0/24",    # Corporate office (update with your real IPs)
          "198.51.100.0/24",    # Branch office (update with your real IPs)
          "49.207.205.136/32"
        ]
      },
      blocked_malicious_ips = {
        ip_address_version = "IPV4"
        addresses = [
          "192.0.2.0/24"       # Known malicious range
        ]
      },
      partner_ips = {
        ip_address_version = "IPV4"
        addresses = [
          "203.0.114.0/24"     # Partner/vendor IPs
        ]
      }
    }

    # Production logging configuration with extended retention
    enable_logging = true
    log_retention_days = 365  # 1 year retention for production compliance
    
    # Privacy-compliant redacted fields for production
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
      Compliance  = "Required"
      Criticality = "High"
    }
  }
}