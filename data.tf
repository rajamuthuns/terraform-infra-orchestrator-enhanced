# Terraform Infrastructure Orchestrator - Data Sources

# VPC discovery for ALB deployment
data "aws_vpc" "selected" {
  for_each = var.alb_spec
  
  filter {
    name   = "tag:Name"
    values = [each.value.vpc_name]
  }
}

# Subnet discovery for ALB deployment
data "aws_subnets" "public" {
  for_each = var.alb_spec
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected[each.key].id]
  }
  
  filter {
    name   = "tag:Name"
    values = try(each.value.subnet_names, ["*public*"])
  }
}


## Terraform Infrastructure Orchestrator - Local Values ##
locals {
  # CloudFront CIDR blocks for security group restrictions
  cloudfront_iprange = [
    "13.32.0.0/15",
    "13.35.0.0/16",
    "18.238.0.0/15",
    "52.84.0.0/15",
    "54.182.0.0/16",
    "54.192.0.0/16",
    "54.230.0.0/16",
    "54.239.128.0/18",
    "54.240.128.0/18",
    "99.84.0.0/16",
    "130.176.0.0/16",
    "205.251.192.0/19"
  ]
}