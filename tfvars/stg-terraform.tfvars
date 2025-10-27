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
    instance_type          = "t3.medium"
    vpc_name               = "dev-mig-target-vpc"
    key_name               = "raja-stg"
    os_type                = "linux"
    ami_name               = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size       = 30

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
        size        = 100
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
    instance_type    = "t3.large"
    vpc_name         = "dev-mig-target-vpc"
    key_name         = "raja-stg"
    os_type          = "linux"
    ami_name         = "amzn2-ami-hvm-*-x86_64-gp2"
    root_volume_size = 50

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
        size        = 200
        type        = "gp3"
        encrypted   = true
      }
    ]
    subnet_name = "dev-mig-private-subnet-2"

    tags = {
      Application = "AppServer"
      OS          = "Linux"
    }
  },

  # Windows Instances
  "windows-webserver" = {
    enable_alb_integration = true
    alb_name               = "windows-alb"
    instance_type          = "t3.large" # Windows typically needs more resources
    vpc_name               = "dev-mig-target-vpc"
    key_name               = "raja-stg"
    os_type                = "windows"
    ami_name               = "Windows_Server-2022-English-Full-Base-*"

    root_volume_size = 80 # Windows needs more space

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
        size        = 200
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
    instance_type    = "t3.xlarge"
    vpc_name         = "dev-mig-target-vpc"
    key_name         = "raja-stg"
    os_type          = "windows"
    ami_name         = "Windows_Server-2019-English-Full-Base-*"
    root_volume_size = 100

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
        size        = 400
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
    distribution_name     = "linux-app-distribution-stg"
    alb_origin           = "linux-alb"  # References the ALB module key
    price_class          = "PriceClass_200"  # More edge locations for staging
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url    = "https://auth.staging.example.com/login"
    
    # Supported CloudFront module parameters
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]
    
    tags = {
      Application = "LinuxWebApp"
      Distribution = "Staging"
    }
  },
  
  windows-cf = {
    distribution_name     = "windows-app-distribution-stg"
    alb_origin           = "windows-alb"  # References the ALB module key
    price_class          = "PriceClass_200"
    ping_auth_cookie_name = "PingAuthCookie"
    ping_redirect_url    = "https://auth.staging.example.com/login"
    
    # Supported CloudFront module parameters
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]
    
    tags = {
      Application = "WindowsWebApp"
      Distribution = "Staging"
    }
  }
}

# WAF Configuration Specifications
waf_spec = {
  cloudfront-waf = {
    scope = "CLOUDFRONT"  # For CloudFront distributions
    protected_distributions = ["linux-cf", "windows-cf"]  # References CloudFront module keys
    
    # AWS Managed Rules - More comprehensive for staging
    enable_all_aws_managed_rules = false
    enabled_aws_managed_rules = [
      "common_rule_set",
      "known_bad_inputs",
      "linux_rule_set",
      "sqli_rule_set",
      "wordpress_rule_set"
    ]
    
    # Custom rules for staging (priorities 11+ to avoid conflicts with AWS managed rules 1-10)
    custom_rules = [
      {
        name                       = "RateLimitRule"
        priority                   = 11
        action                     = "block"
        type                       = "rate_based"
        limit                      = 1000  # Stricter than dev
        aggregate_key_type         = "IP"
        cloudwatch_metrics_enabled = true
        metric_name                = "RateLimitRule"
        sampled_requests_enabled   = true
      },
      {
        name                       = "GeoBlockRule"
        priority                   = 12
        action                     = "block"
        type                       = "geo_match"
        country_codes              = ["CN", "RU"]  # Block certain countries in staging
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoBlockRule"
        sampled_requests_enabled   = true
      }
    ]
    
    # IP sets for staging
    ip_sets = {
      staging_allowed_ips = {
        ip_address_version = "IPV4"
        addresses          = ["203.0.113.0/24", "198.51.100.0/24", "192.0.2.0/24"]
      }
    }
    
    # Logging configuration
    enable_logging = false
    log_destination_configs = [
      "arn:aws:logs:us-east-1:137617557860:log-group:aws-waf-logs-staging"
    ]
    
    tags = {
      Purpose = "CloudFrontProtection"
      Environment = "Staging"
    }
  }
}