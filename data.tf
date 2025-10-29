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