# Production Environment Configuration Values
# These values are specific to the production environment

# Project configuration
project_name = "terraform-infra-orchestrator"
gitlab_host  = "gitlab.aws.dev"
gitlab_org   = "sunrajam"

# Base modules configuration
base_modules = {
  ec2 = {
    repository = "ec2-base-module"
    version    = "main"
  }
  alb = {
    repository = "tf-alb"
    version    = "main"
  }
}

# Primary module for this deployment
primary_module = "ec2"

# AWS configuration
account_id  = "221106935066"
aws_region  = "us-east-1"
environment = "prod"

alb_spec = {
  linux-alb = {
    vpc_name             = "prod-mig-target-vpc"
    http_enabled         = false # HTTPS only in production
    https_enabled        = true
    name                 = "linux-alb"
    health_check_path    = "/health"
    health_check_matcher = "200"
    # certificate_arn = "arn:aws:acm:us-east-1:account:certificate/cert-id"
  },
  windows-alb = {
    vpc_name             = "prod-mig-target-vpc"
    http_enabled         = false # HTTPS only in production
    https_enabled        = true
    name                 = "windows-alb"
    health_check_path    = "/health"
    health_check_matcher = "200"
    # certificate_arn = "arn:aws:acm:us-east-1:account:certificate/cert-id"
  }
}

ec2_spec = {
  # Linux Instances
  "linux-webserver" = {
    enable_alb_integration = true
    alb_name               = "linux-alb"
    instance_type          = "t3.large" # Production sizing
    vpc_name               = "prod-mig-target-vpc"
    key_name               = "raja-prod"
    os_type                = "linux"
    ami_name               = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size       = 50

    # Linux-specific security group rules
    ingress_rules = [
      {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["10.0.1.0/24"] # Bastion subnet only
        description = "SSH access from bastion host"
      },
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTPS access"
      }
    ]

    additional_ebs_volumes = [
      {
        device_name = "/dev/sdf"
        size        = 200
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "prod-mig-private-subnet-1"

    tags = {
      Application = "WebServer"
      OS          = "Linux"
      Backup      = "Required"
    }
  },

  "linux-appserver" = {
    instance_type    = "t3.xlarge" # Production sizing
    vpc_name         = "prod-mig-target-vpc"
    key_name         = "raja-prod"
    os_type          = "linux"
    ami_name         = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size = 100

    ingress_rules = [
      {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["10.0.1.0/24"] # Bastion subnet only
        description = "SSH access from bastion host"
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
        size        = 500
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "prod-mig-private-subnet-2"

    tags = {
      Application = "AppServer"
      OS          = "Linux"
      Backup      = "Required"
    }
  },

  # Windows Instances
  "windows-webserver" = {
    enable_alb_integration = true
    alb_name               = "windows-alb"
    instance_type          = "t3.xlarge" # Production sizing
    vpc_name               = "prod-mig-target-vpc"
    key_name               = "raja-prod"
    os_type                = "windows"
    ami_name               = "Windows_Server-2022-English-Full-Base-*"

    root_volume_size = 100 # Windows needs more space

    # Windows-specific security group rules
    ingress_rules = [
      {
        from_port   = 3389
        to_port     = 3389
        protocol    = "tcp"
        cidr_blocks = ["10.0.1.0/24"] # Bastion subnet only
        description = "RDP access from bastion host"
      },
      {
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTPS access"
      }
    ]

    additional_ebs_volumes = [
      {
        device_name = "/dev/sdf" # Windows will see this as D: drive
        size        = 500
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "prod-mig-private-subnet-1"

    tags = {
      Application = "WebServer"
      OS          = "Windows2022"
      Backup      = "Required"
    }
  },

  "windows-appserver" = {
    instance_type    = "t3.2xlarge" # Production sizing
    vpc_name         = "prod-mig-target-vpc"
    key_name         = "raja-prod"
    os_type          = "windows"
    ami_name         = "Windows_Server-2019-English-Full-Base-*"
    root_volume_size = 200

    ingress_rules = [
      {
        from_port   = 3389
        to_port     = 3389
        protocol    = "tcp"
        cidr_blocks = ["10.0.1.0/24"] # Bastion subnet only
        description = "RDP access from bastion host"
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
        size        = 1000
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "prod-mig-private-subnet-2"

    tags = {
      Application = "AppServer"
      OS          = "Windows2019"
      Backup      = "Required"
    }
  }
}

# CloudFront Distribution Specifications
cloudfront_spec = {
  linux-cf = {
    distribution_name      = "linux-app-distribution-prod"
    alb_origin            = "linux-alb"  # References the ALB module key
    price_class           = "PriceClass_All"  # Global distribution for production
    default_root_object   = "index.html"
    compress              = true
    viewer_protocol_policy = "https-only"  # HTTPS only in production
    origin_protocol_policy = "https-only"  # HTTPS to origin in production
    origin_https_port     = 443
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url     = "https://auth.example.com/login"
    
    tags = {
      Application = "LinuxWebApp"
      Distribution = "Production"
      Backup = "Required"
    }
  },
  
  windows-cf = {
    distribution_name      = "windows-app-distribution-prod"
    alb_origin            = "windows-alb"  # References the ALB module key
    price_class           = "PriceClass_All"
    default_root_object   = "default.aspx"
    compress              = true
    viewer_protocol_policy = "https-only"
    origin_protocol_policy = "https-only"
    origin_https_port     = 443
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url     = "https://auth.example.com/login"
    
    tags = {
      Application = "WindowsWebApp"
      Distribution = "Production"
      Backup = "Required"
    }
  }
}

# WAF Configuration Specifications
waf_spec = {
  cloudfront-waf = {
    scope = "CLOUDFRONT"  # For CloudFront distributions
    protected_distributions = ["linux-cf", "windows-cf"]  # References CloudFront module keys
    
    # AWS Managed Rules - Comprehensive production security
    enable_all_aws_managed_rules = false
    enabled_aws_managed_rules = [
      "AWSManagedRulesCommonRuleSet",
      "AWSManagedRulesKnownBadInputsRuleSet",
      "AWSManagedRulesLinuxRuleSet",
      "AWSManagedRulesWindowsRuleSet",
      "AWSManagedRulesSQLiRuleSet",
      "AWSManagedRulesWordPressRuleSet",
      "AWSManagedRulesAmazonIpReputationList",
      "AWSManagedRulesAnonymousIpList",
      "AWSManagedRulesBotControlRuleSet"
    ]
    
    # Production custom rules
    custom_rules = [
      {
        name     = "ProductionRateLimitRule"
        priority = 1
        action   = "block"
        
        statement = {
          rate_based_statement = {
            limit              = 500  # Strict rate limiting for production
            aggregate_key_type = "IP"
          }
        }
        
        visibility_config = {
          cloudwatch_metrics_enabled = true
          metric_name                = "ProductionRateLimitRule"
          sampled_requests_enabled   = true
        }
      },
      {
        name     = "ProductionGeoBlockRule"
        priority = 2
        action   = "block"
        
        statement = {
          geo_match_statement = {
            country_codes = ["CN", "RU", "KP", "IR"]  # Block high-risk countries
          }
        }
        
        visibility_config = {
          cloudwatch_metrics_enabled = true
          metric_name                = "ProductionGeoBlockRule"
          sampled_requests_enabled   = true
        }
      },
      {
        name     = "ProductionSizeRestrictionRule"
        priority = 3
        action   = "block"
        
        statement = {
          size_constraint_statement = {
            field_to_match = {
              body = {}
            }
            comparison_operator = "GT"
            size               = 8192  # 8KB limit
            text_transformations = [
              {
                priority = 0
                type     = "NONE"
              }
            ]
          }
        }
        
        visibility_config = {
          cloudwatch_metrics_enabled = true
          metric_name                = "ProductionSizeRestrictionRule"
          sampled_requests_enabled   = true
        }
      }
    ]
    
    # IP sets for production
    ip_sets = {
      production_allowed_ips = {
        name               = "production-allowed-ips"
        description        = "Production allowed IP addresses"
        scope              = "CLOUDFRONT"
        ip_address_version = "IPV4"
        addresses          = ["203.0.113.0/24"]  # Only corporate IPs
      },
      production_blocked_ips = {
        name               = "production-blocked-ips"
        description        = "Production blocked IP addresses"
        scope              = "CLOUDFRONT"
        ip_address_version = "IPV4"
        addresses          = []  # Populated as needed
      }
    }
    
    # Comprehensive logging for production
    enable_logging = true
    log_destination_configs = [
      {
        resource_arn = "arn:aws:logs:us-east-1:221106935066:log-group:aws-waf-logs-production"
      }
    ]
    
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
      Purpose = "CloudFrontProtection"
      Environment = "Production"
      Compliance = "Required"
      Backup = "Required"
    }
  }
}