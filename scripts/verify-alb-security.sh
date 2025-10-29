#!/bin/bash

# ALB-CloudFront Security Verification Script
# This script verifies that ALB is properly restricted to CloudFront traffic only

set -e

echo "🔒 ALB-CloudFront Security Verification"
echo "======================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get Terraform outputs
echo "📊 Getting infrastructure details..."

# Get ALB DNS name
ALB_DNS=$(terraform output -json alb_endpoints 2>/dev/null | jq -r '.["linux-alb"]' 2>/dev/null || echo "")
if [ -z "$ALB_DNS" ]; then
    echo -e "${YELLOW}⚠️  Could not get ALB DNS name from Terraform outputs${NC}"
    echo "Please ensure Terraform has been applied and outputs are available"
    exit 1
fi

# Get CloudFront domain
CF_DOMAIN=$(terraform output -json cloudfront_endpoints 2>/dev/null | jq -r '.["linux-cf"]' 2>/dev/null || echo "")
if [ -z "$CF_DOMAIN" ]; then
    echo -e "${YELLOW}⚠️  Could not get CloudFront domain from Terraform outputs${NC}"
    echo "Please ensure Terraform has been applied an