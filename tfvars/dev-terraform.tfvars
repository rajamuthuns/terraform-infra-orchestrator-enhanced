# Development Environment Configuration Values
# These values are specific to the development environment

# Project configuration
project_name = "terraform-infra-orchestrator"

# AWS configuration
account_id  = "221106935066"
aws_region  = "us-east-1"
environment = "dev"

alb_spec = {
  linux-alb = {
    vpc_name              = "dev-mig-target-vpc"
    subnet_names          = ["dev-mig-public-subnet-*"]
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
    vpc_name              = "dev-mig-target-vpc"
    subnet_names          = ["dev-mig-public-subnet-*"]
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
  # Linux Instances
  "linux-webserver" = {
    enable_alb_integration = true
    alb_name               = "linux-alb"
    instance_type          = "t3.small"
    vpc_name               = "dev-mig-target-vpc"
    key_name               = "raja-dev"
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
        size        = 50
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-1"

    tags = {
      Application = "WebServer"
      OS          = "Linux"
    }
  },

  "linux-appserver" = {
    instance_type    = "t3.medium"
    vpc_name         = "dev-mig-target-vpc"
    key_name         = "raja-dev"
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
    subnet_name = "dev-mig-private-subnet-2"

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
    vpc_name               = "dev-mig-target-vpc"
    key_name               = "raja-dev"
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
        size        = 100
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-1"

    tags = {
      Application = "WebServer"
      OS          = "Windows2022"
    }
  },

  "windows-appserver" = {
    instance_type    = "t3.large"
    vpc_name         = "dev-mig-target-vpc"
    key_name         = "raja-dev"
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
    subnet_name = "dev-mig-private-subnet-2"

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
    alb_origin            = "linux-alb"      # References the ALB module key
    waf_key               = "cloudfront-waf" # References the WAF module key
    price_class           = "PriceClass_100"
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url     = "https://auth.dev.example.com/login"

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
    alb_origin            = "windows-alb"    # References the ALB module key
    waf_key               = "cloudfront-waf" # References the WAF module key
    price_class           = "PriceClass_100"
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url     = "https://auth.dev.example.com/login"

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
    scope = "CLOUDFRONT" # For CloudFront distributions
    default_action = "allow"  # Allow by default, block with specific rules

    # Comprehensive AWS Managed Rules for maximum protection
    enable_all_aws_managed_rules = false
    enabled_aws_managed_rules = [
      "common_rule_set",  # Core protection (OWASP Top 10)
      "known_bad_inputs", # Malicious input protection
      "sqli_rule_set",    # SQL injection protection
      "ip_reputation",    # Bad IP blocking
      "linux_rule_set",   # Linux-specific attacks
      "bot_control",      # Bot protection
      "anonymous_ip",     # Anonymous IP blocking
      "wordpress_rule_set", # WordPress protection
      "php_rule_set"      # PHP application protection
    ]

    # Production-grade custom rules with layered security
    custom_rules = [
      {
        name                       = "AggressiveRateLimit"
        priority                   = 11
        action                     = "block"
        type                       = "rate_based"
        limit                      = 300 # 300 requests per 5 minutes
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
        country_codes              = ["CN", "RU", "KP", "IR", "SY", "AF", "IQ"] # Expanded high-risk countries
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoBlockHighRisk"
        sampled_requests_enabled   = true
      },
      {
        name                       = "BlockMaliciousIPs"
        priority                   = 13
        action                     = "block"
        type                       = "ip_set"
        ip_set_arn                 = "blocked_malicious_ips"
        cloudwatch_metrics_enabled = true
        metric_name                = "BlockMaliciousIPs"
        sampled_requests_enabled   = true
      }
    ]

    # Enhanced IP sets for comprehensive security
    ip_sets = {
      trusted_office_ips = {
        ip_address_version = "IPV4"
        addresses = [
          "203.0.113.0/24",  # Corporate office (update with your real IPs)
          "198.51.100.0/24", # Branch office (update with your real IPs)
          "49.207.205.136/32"
        ]
      },
      blocked_malicious_ips = {
        ip_address_version = "IPV4"
        addresses = [
          "192.0.2.0/24" # Known malicious range
        ]
      }
    }

    # Production logging configuration
    enable_logging     = true
    log_retention_days = 180 # 6 months retention for compliance
    log_destination_configs = ["arn:aws:logs:us-east-1:221106935066:log-group:aws-waf-logs-dev"]

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
      Environment = "Development"
      Security    = "Maximum"
    }
  },

  # Regional WAF for ALB (CloudFront IP Enforcement)
  alb-regional-waf = {
    scope          = "REGIONAL" # For ALB protection
    default_action = "block"    # Block by default, allow only CloudFront IPs
    protected_albs = ["linux-alb", "windows-alb"] # ALBs to protect

    # Disable AWS managed rules for this WAF (only need CloudFront IP allow)
    enable_all_aws_managed_rules = false
    enabled_aws_managed_rules    = []

    # CloudFront IP Allow Rule
    custom_rules = [
      {
        name                       = "AllowCloudFrontIPs"
        priority                   = 1
        action                     = "allow"
        type                       = "ip_set"
        ip_set_arn                 = "cloudfront_ips"
        cloudwatch_metrics_enabled = true
        metric_name                = "AllowCloudFrontIPs"
        sampled_requests_enabled   = true
      }
    ]

    # Complete Official CloudFront IP ranges (Global + Regional Edge)
    ip_sets = {
      cloudfront_ips = {
        ip_address_version = "IPV4"
        addresses = [
          # CLOUDFRONT_GLOBAL_IP_LIST
          "120.52.22.96/27", "205.251.249.0/24", "180.163.57.128/26", "204.246.168.0/22", "111.13.171.128/26", "18.160.0.0/15", "205.251.252.0/23", "54.192.0.0/16", "204.246.173.0/24", "54.230.200.0/21", "120.253.240.192/26", "116.129.226.128/26", "130.176.0.0/17", "3.173.192.0/18", "108.156.0.0/14", "99.86.0.0/16", "13.32.0.0/15", "120.253.245.128/26", "13.224.0.0/14", "70.132.0.0/18", "15.158.0.0/16", "111.13.171.192/26", "13.249.0.0/16", "18.238.0.0/15", "18.244.0.0/15", "205.251.208.0/20", "3.165.0.0/16", "3.168.0.0/14", "65.9.128.0/18", "130.176.128.0/18", "58.254.138.0/25", "205.251.206.0/23", "54.230.208.0/20", "3.160.0.0/14", "116.129.226.0/25", "23.91.0.0/19", "52.222.128.0/17", "18.164.0.0/15", "111.13.185.32/27", "64.252.128.0/18", "205.251.254.0/24", "3.166.0.0/15", "54.230.224.0/19", "71.152.0.0/17", "216.137.32.0/19", "204.246.172.0/24", "205.251.202.0/23", "18.172.0.0/15", "120.52.39.128/27", "118.193.97.64/26", "3.164.64.0/18", "18.154.0.0/15", "3.173.0.0/17", "54.240.128.0/18", "205.251.250.0/23", "180.163.57.0/25", "52.46.0.0/18", "3.174.0.0/15", "52.82.128.0/19", "54.230.0.0/17", "54.230.128.0/18", "54.239.128.0/18", "130.176.224.0/20", "36.103.232.128/26", "52.84.0.0/15", "143.204.0.0/16", "144.220.0.0/16", "120.52.153.192/26", "119.147.182.0/25", "120.232.236.0/25", "111.13.185.64/27", "3.164.0.0/18", "3.172.64.0/18", "54.182.0.0/16", "58.254.138.128/26", "120.253.245.192/27", "54.239.192.0/19", "18.68.0.0/16", "18.64.0.0/14", "120.52.12.64/26", "24.110.32.0/19", "99.84.0.0/16", "205.251.204.0/23", "130.176.192.0/19", "52.124.128.0/17", "204.246.164.0/22", "13.35.0.0/16", "204.246.174.0/23", "3.164.128.0/17", "3.172.0.0/18", "36.103.232.0/25", "119.147.182.128/26", "118.193.97.128/25", "120.232.236.128/26", "204.246.176.0/20", "65.8.0.0/16", "65.9.0.0/17", "108.138.0.0/15", "120.253.241.160/27", "3.173.128.0/18", "64.252.64.0/18",
          # CLOUDFRONT_REGIONAL_EDGE_IP_LIST
          "13.113.196.64/26", "13.113.203.0/24", "52.199.127.192/26", "57.182.253.0/24", "57.183.42.0/25", "13.124.199.0/24", "3.35.130.128/25", "52.78.247.128/26", "13.203.133.0/26", "13.233.177.192/26", "15.207.13.128/25", "15.207.213.128/25", "52.66.194.128/26", "13.228.69.0/24", "47.129.82.0/24", "47.129.83.0/24", "47.129.84.0/24", "52.220.191.0/26", "13.210.67.128/26", "13.54.63.128/26", "3.107.43.128/25", "3.107.44.0/25", "3.107.44.128/25", "43.218.56.128/26", "43.218.56.192/26", "43.218.56.64/26", "43.218.71.0/26", "99.79.169.0/24", "18.192.142.0/23", "18.199.68.0/22", "18.199.72.0/22", "18.199.76.0/22", "35.158.136.0/24", "52.57.254.0/24", "18.200.212.0/23", "52.212.248.0/26", "13.134.24.0/23", "13.134.94.0/23", "18.175.65.0/24", "18.175.66.0/24", "18.175.67.0/24", "3.10.17.128/25", "3.11.53.0/24", "52.56.127.0/25", "15.188.184.0/24", "51.44.234.0/23", "51.44.236.0/23", "51.44.238.0/23", "52.47.139.0/24", "3.29.40.128/26", "3.29.40.192/26", "3.29.40.64/26", "3.29.57.0/26", "18.229.220.192/26", "18.230.229.0/24", "18.230.230.0/25", "54.233.255.128/26", "56.125.46.0/24", "56.125.47.0/32", "56.125.48.0/24", "3.231.2.0/25", "3.234.232.224/27", "3.236.169.192/26", "3.236.48.0/23", "34.195.252.0/24", "34.226.14.0/24", "44.220.194.0/23", "44.220.196.0/23", "44.220.198.0/23", "44.220.200.0/23", "44.220.202.0/23", "44.222.66.0/24", "13.59.250.0/26", "18.216.170.128/25", "3.128.93.0/24", "3.134.215.0/24", "3.146.232.0/22", "3.147.164.0/22", "3.147.244.0/22", "52.15.127.128/26", "3.101.158.0/23", "52.52.191.128/26", "34.216.51.0/25", "34.223.12.224/27", "34.223.80.192/26", "35.162.63.192/26", "35.167.191.128/26", "35.93.168.0/23", "35.93.170.0/23", "35.93.172.0/23", "44.227.178.0/24", "44.234.108.128/25", "44.234.90.252/30"
        ]
      }
    }

    enable_logging     = false # Disable to avoid log group conflict
    log_retention_days = 90

    tags = {
      Purpose     = "ALBCloudFrontIPEnforcement"
      Environment = "Development"
      Security    = "CloudFrontOnly"
      IPRanges    = "Official-AWS-Complete"
    }
  }
}
