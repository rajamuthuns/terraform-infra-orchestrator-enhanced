# Development Environment Configuration Values
# These values are specific to the development environment

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
environment = "dev"

alb_spec = {
  linux-alb = {
    vpc_name             = "dev-mig-target-vpc"
    http_enabled         = true
    https_enabled        = false
    name                 = "linux-alb"
    health_check_path    = "/health"
    health_check_matcher = "200"
  },
  windows-alb = {
    vpc_name             = "dev-mig-target-vpc"
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
    vpc_name               = "dev-mig-target-vpc"
    key_name               = "raja-dev"
    os_type                = "linux"
    ami_name               = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size       = 20

    # Linux-specific security group rules
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
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTP access"
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

    # Windows-specific security group rules
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
        cidr_blocks = ["0.0.0.0/0"]
        description = "HTTP access"
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
    distribution_name      = "linux-app-distribution"
    alb_origin            = "linux-alb"  # References the ALB module key
    price_class           = "PriceClass_100"
    default_root_object   = "index.html"
    compress              = true
    viewer_protocol_policy = "redirect-to-https"
    origin_protocol_policy = "http-only"
    origin_http_port      = 80
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url     = "https://auth.dev.example.com/login"
    
    tags = {
      Application = "LinuxWebApp"
      Distribution = "Primary"
    }
  },
  
  windows-cf = {
    distribution_name      = "windows-app-distribution"
    alb_origin            = "windows-alb"  # References the ALB module key
    price_class           = "PriceClass_100"
    default_root_object   = "default.aspx"
    compress              = true
    viewer_protocol_policy = "redirect-to-https"
    origin_protocol_policy = "http-only"
    origin_http_port      = 80
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url     = "https://auth.dev.example.com/login"
    
    tags = {
      Application = "WindowsWebApp"
      Distribution = "Primary"
    }
  }
}

# WAF Configuration Specifications
waf_spec = {
  cloudfront-waf = {
    scope = "CLOUDFRONT"  # For CloudFront distributions
    protected_distributions = ["linux-cf", "windows-cf"]  # References CloudFront module keys
    
    # AWS Managed Rules
    enable_all_aws_managed_rules = false
    enabled_aws_managed_rules = [
      "AWSManagedRulesCommonRuleSet",
      "AWSManagedRulesKnownBadInputsRuleSet",
      "AWSManagedRulesLinuxRuleSet",
      "AWSManagedRulesWindowsRuleSet"
    ]
    
    # Custom rules for development
    custom_rules = [
      {
        name     = "RateLimitRule"
        priority = 1
        action   = "block"
        
        statement = {
          rate_based_statement = {
            limit              = 2000
            aggregate_key_type = "IP"
          }
        }
        
        visibility_config = {
          cloudwatch_metrics_enabled = true
          metric_name                = "RateLimitRule"
          sampled_requests_enabled   = true
        }
      }
    ]
    
    # IP sets for development
    ip_sets = {
      dev_allowed_ips = {
        name               = "dev-allowed-ips"
        description        = "Development allowed IP addresses"
        scope              = "CLOUDFRONT"
        ip_address_version = "IPV4"
        addresses          = ["203.0.113.0/24", "198.51.100.0/24"]  # Example dev office IPs
      }
    }
    
    # Logging configuration
    enable_logging = true
    log_destination_configs = [
      {
        resource_arn = "arn:aws:logs:us-east-1:221106935066:log-group:aws-waf-logs-dev"
      }
    ]
    
    tags = {
      Purpose = "CloudFrontProtection"
      Environment = "Development"
    }
  }
}