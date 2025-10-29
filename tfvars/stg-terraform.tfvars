# Staging Environment Configuration Values
# These values are specific to the staging environment
# Enhanced configuration for staging validation with same infrastructure base as dev

# Project configuration
project_name = "terraform-infra-orchestrator"

# AWS configuration - Keep same as dev
account_id  = "137617557860"
aws_region  = "us-east-1"
environment = "stg"

alb_spec = {
  linux-alb = {
    vpc_name      = "dev-mig-target-vpc"
    http_enabled  = true
    https_enabled = true
    //certificate_arn       = "arn:aws:acm:us-east-1:221106935066:certificate/e1ace7b1-f324-4ac6-aff3-7ec67edc8622"
    name                  = "linux-alb"
    health_check_path     = "/health"
    health_check_matcher  = "200"
    target_group_port     = 80
    target_group_protocol = "HTTP"
  },
  windows-alb = {
    vpc_name      = "dev-mig-target-vpc"
    http_enabled  = true
    https_enabled = true
    //certificate_arn       = "arn:aws:acm:us-east-1:221106935066:certificate/e1ace7b1-f324-4ac6-aff3-7ec67edc8622"
    name                  = "windows-alb"
    health_check_path     = "/health.txt"
    health_check_matcher  = "200"
    target_group_port     = 80
    target_group_protocol = "HTTP"
  }
}

ec2_spec = {
  # Linux Instances - Enhanced for staging validation
  "linux-webserver" = {
    enable_alb_integration = true
    alb_name               = "linux-alb"
    instance_type          = "t3.small" # Enhanced from dev t3.micro
    vpc_name               = "dev-mig-target-vpc"
    key_name               = "raja-stg"
    os_type                = "linux"
    ami_name               = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size       = 30 # Enhanced from dev 20GB

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
        size        = 100 # Enhanced from dev 50GB
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-1"

    tags = {
      Application = "WebServer"
      OS          = "Linux"
      Environment = "Staging"
    }
  },

  "linux-appserver" = {
    instance_type    = "t3.medium" # Enhanced from dev t3.medium
    vpc_name         = "dev-mig-target-vpc"
    key_name         = "raja-stg"
    os_type          = "linux"
    ami_name         = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size = 50 # Enhanced from dev 30GB

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
        size        = 200 # Enhanced from dev 100GB
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-2"

    tags = {
      Application = "AppServer"
      OS          = "Linux"
      Environment = "Staging"
    }
  },

  # Windows Instances - Enhanced for staging validation
  "windows-webserver" = {
    enable_alb_integration = true
    alb_name               = "windows-alb"
    instance_type          = "t3.medium" # Same as dev (Windows needs resources)
    vpc_name               = "dev-mig-target-vpc"
    key_name               = "raja-stg"
    os_type                = "windows"
    ami_name               = "Windows_Server-2022-English-Full-Base-*"

    root_volume_size = 80 # Enhanced from dev 50GB

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
        size        = 200        # Enhanced from dev 100GB
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-1"

    tags = {
      Application = "WebServer"
      OS          = "Windows2022"
      Environment = "Staging"
    }
  },

  "windows-appserver" = {
    instance_type    = "t3.large" # Same as dev
    vpc_name         = "dev-mig-target-vpc"
    key_name         = "raja-stg"
    os_type          = "windows"
    ami_name         = "Windows_Server-2019-English-Full-Base-*"
    root_volume_size = 100 # Enhanced from dev 80GB

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
        size        = 300        # Enhanced from dev 200GB
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-2"

    tags = {
      Application = "AppServer"
      OS          = "Windows2019"
      Environment = "Staging"
    }
  }
}

# CloudFront Distribution Specifications - Staging Environment
cloudfront_spec = {
  linux-cf = {
    distribution_name     = "linux-app-distribution-staging"
    alb_origin            = "linux-alb"      # References the ALB module key
    waf_key               = "cloudfront-waf" # References the WAF module key
    price_class           = "PriceClass_100"
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url     = "https://auth.staging.example.com/login"

    # Supported CloudFront module parameters
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    tags = {
      Application  = "LinuxWebApp"
      Distribution = "Staging"
      Environment  = "Staging"
    }
  },

  windows-cf = {
    distribution_name     = "windows-app-distribution-staging"
    alb_origin            = "windows-alb"    # References the ALB module key
    waf_key               = "cloudfront-waf" # References the WAF module key
    price_class           = "PriceClass_100"
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url     = "https://auth.staging.example.com/login"

    # Supported CloudFront module parameters
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    tags = {
      Application  = "WindowsWebApp"
      Distribution = "Staging"
      Environment  = "Staging"
    }
  }
}

# WAF Configuration Specifications - Staging Environment (Production-like Security)
waf_spec = {
  cloudfront-waf = {
    scope = "CLOUDFRONT" # For CloudFront distributions

    # Production-like AWS Managed Rules for staging validation
    enable_all_aws_managed_rules = false
    enabled_aws_managed_rules = [
      "common_rule_set",  # Core protection
      "known_bad_inputs", # Malicious input protection
      "sqli_rule_set",    # SQL injection protection
      "ip_reputation",    # Bad IP blocking
      "linux_rule_set",   # Linux-specific attacks
      "bot_control",      # Bot protection
      "anonymous_ip"      # Anonymous IP blocking
    ]

    # Staging-specific custom rules (less aggressive than production)
    custom_rules = [
      {
        name                       = "StagingRateLimit"
        priority                   = 11
        action                     = "block"
        type                       = "rate_based"
        limit                      = 500 # More lenient than production
        aggregate_key_type         = "IP"
        cloudwatch_metrics_enabled = true
        metric_name                = "StagingRateLimit"
        sampled_requests_enabled   = true
      },
      {
        name                       = "StagingGeoBlock"
        priority                   = 12
        action                     = "block"
        type                       = "geo_match"
        country_codes              = ["CN", "RU", "KP"] # Fewer countries than production
        cloudwatch_metrics_enabled = true
        metric_name                = "StagingGeoBlock"
        sampled_requests_enabled   = true
      }
    ]

    # Enhanced IP sets for staging testing
    ip_sets = {
      trusted_office_ips = {
        ip_address_version = "IPV4"
        addresses = [
          "203.0.113.0/24",  # Corporate office (update with your real IPs)
          "198.51.100.0/24", # Branch office (update with your real IPs)
          "49.207.205.136/32"
        ]
      },
      staging_test_ips = {
        ip_address_version = "IPV4"
        addresses = [
          "192.0.2.0/24" # Test IP range for staging
        ]
      }
    }

    # Staging logging configuration
    enable_logging     = true
    log_retention_days = 90 # 3 months retention for staging

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
      Purpose     = "StagingCloudFrontProtection"
      Environment = "Staging"
      Security    = "Production-like"
    }
  }
}
