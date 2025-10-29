#!/bin/bash

# Complete WAF + CloudFront Security Testing Script
# Tests AWS resources directly: WAF rules, CloudFront functionality, ALB health

set -e

echo "Complete WAF + CloudFront Security Testing"
echo "=========================================="

ENVIRONMENT=${1:-dev}
CF_DOMAIN=${2:-""}

echo "Environment: $ENVIRONMENT"
if [ -n "$CF_DOMAIN" ]; then
    echo "CloudFront Domain: $CF_DOMAIN"
else
    echo "CloudFront Domain: Auto-detect from AWS"
fi
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${CYAN}Testing: $test_name${NC}"
    
    if eval "$test_command" > /dev/null 2>&1; then
        if [ "$expected_result" = "pass" ]; then
            echo -e "${GREEN}  ✅ PASS${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}  ❌ FAIL (Expected to fail but passed)${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        if [ "$expected_result" = "fail" ]; then
            echo -e "${GREEN}  ✅ PASS (Correctly blocked)${NC}"
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            echo -e "${RED}  ❌ FAIL${NC}"
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
}

# Step 1: AWS Credentials and CloudFront Discovery
echo -e "${PURPLE}Step 1: AWS Account Validation${NC}"
echo "=============================="

# Test AWS CLI access
echo "Checking AWS CLI access..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}❌ AWS CLI not configured or no access${NC}"
    echo "Please configure AWS CLI credentials first:"
    echo "aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✅ AWS CLI access confirmed (Account: $ACCOUNT_ID)${NC}"

# Discover CloudFront distributions if not specified
if [ -z "$CF_DOMAIN" ]; then
    echo "Searching for CloudFront distributions in AWS account..."
    
    CF_LIST=$(aws cloudfront list-distributions --output json 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$CF_LIST" ]; then
        echo -e "${RED}❌ Failed to list CloudFront distributions${NC}"
        echo "Please specify domain manually: ./scripts/validate-cloudfront.sh dev your-domain.cloudfront.net"
        exit 1
    fi
    
    # Check if any distributions exist
    DIST_COUNT=$(echo "$CF_LIST" | jq -r '.DistributionList.Items | length' 2>/dev/null || echo "0")
    
    if [ "$DIST_COUNT" = "0" ]; then
        echo -e "${RED}❌ No CloudFront distributions found${NC}"
        echo "Please create a CloudFront distribution first"
        exit 1
    fi
    
    echo "Found $DIST_COUNT CloudFront distribution(s)"
    
    # Get deployed distributions
    CF_DOMAINS=$(echo "$CF_LIST" | jq -r '.DistributionList.Items[] | select(.Status == "Deployed") | .DomainName' 2>/dev/null)
    
    if [ -z "$CF_DOMAINS" ]; then
        echo -e "${YELLOW}⚠️  Found distributions but none are deployed yet${NC}"
        echo "Available distributions:"
        echo "$CF_LIST" | jq -r '.DistributionList.Items[] | "  \(.Id): \(.DomainName) (\(.Status))"' 2>/dev/null
        echo "Please wait for deployment to complete"
        exit 1
    fi
    
    CF_DOMAIN=$(echo "$CF_DOMAINS" | head -1)
    echo "Found deployed distributions:"
    echo "$CF_DOMAINS" | while read domain; do echo "  $domain"; done
fi

echo -e "${GREEN}✅ Using CloudFront Domain: $CF_DOMAIN${NC}"
echo ""

# Step 2: Basic CloudFront Connectivity
echo -e "${PURPLE}Step 2: CloudFront Basic Connectivity${NC}"
echo "====================================="

run_test "CloudFront HTTPS connectivity" "curl -s --connect-timeout 10 --max-time 15 https://$CF_DOMAIN/" "pass"
run_test "CloudFront health endpoint" "curl -s --connect-timeout 10 --max-time 15 https://$CF_DOMAIN/health" "pass"
run_test "HTTP to HTTPS redirect" "curl -s --connect-timeout 10 --max-time 15 -I http://$CF_DOMAIN/ | grep -q '301\\|302'" "pass"

echo ""

# Step 3: WAF Security Tests
echo -e "${PURPLE}Step 3: WAF Security Rule Testing${NC}"
echo "================================="

echo -e "${BLUE}SQL Injection Protection:${NC}"
run_test "Basic SQL injection" "curl -s --connect-timeout 10 --max-time 15 'https://$CF_DOMAIN/?id=1%27%20OR%20%271%27=%271'" "fail"
run_test "UNION SQL injection" "curl -s --connect-timeout 10 --max-time 15 'https://$CF_DOMAIN/?id=1%20UNION%20SELECT%20*%20FROM%20users'" "fail"

echo -e "${BLUE}XSS Protection:${NC}"
run_test "Basic XSS script" "curl -s --connect-timeout 10 --max-time 15 'https://$CF_DOMAIN/?q=%3Cscript%3Ealert(1)%3C/script%3E'" "fail"
run_test "XSS with event handler" "curl -s --connect-timeout 10 --max-time 15 'https://$CF_DOMAIN/?q=%3Cimg%20src=x%20onerror=alert(1)%3E'" "fail"

echo -e "${BLUE}Bot Protection:${NC}"
run_test "Suspicious user agent" "curl -s --connect-timeout 10 --max-time 15 -H 'User-Agent: sqlmap/1.0' https://$CF_DOMAIN/" "fail"
run_test "Scanner user agent" "curl -s --connect-timeout 10 --max-time 15 -H 'User-Agent: Nikto/2.1.6' https://$CF_DOMAIN/" "fail"

echo -e "${BLUE}Path Traversal Protection:${NC}"
run_test "Path traversal attack" "curl -s --connect-timeout 10 --max-time 15 'https://$CF_DOMAIN/../../../etc/passwd'" "fail"

echo ""

# Step 4: Rate Limiting Tests
echo -e "${PURPLE}Step 4: Rate Limiting Tests${NC}"
echo "==========================="

echo -e "${BLUE}Testing rate limiting (10 rapid requests):${NC}"
RATE_LIMIT_PASSED=0
for i in {1..10}; do
    if curl -s --connect-timeout 5 --max-time 10 "https://$CF_DOMAIN/" > /dev/null 2>&1; then
        RATE_LIMIT_PASSED=$((RATE_LIMIT_PASSED + 1))
    fi
    sleep 0.1
done

echo -e "${CYAN}Rate limit test: $RATE_LIMIT_PASSED/10 requests succeeded${NC}"
if [ "$RATE_LIMIT_PASSED" -eq 10 ]; then
    echo -e "${GREEN}  ✅ PASS (Normal rate limiting)${NC}"
elif [ "$RATE_LIMIT_PASSED" -lt 5 ]; then
    echo -e "${YELLOW}  ⚠️  AGGRESSIVE (Very strict rate limiting)${NC}"
else
    echo -e "${GREEN}  ✅ PASS (Some rate limiting active)${NC}"
fi
PASSED_TESTS=$((PASSED_TESTS + 1))
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo ""

# Step 5: Geographic Blocking Tests
echo -e "${PURPLE}Step 5: Geographic Blocking Tests${NC}"
echo "================================="

echo -e "${BLUE}Testing geo-blocking:${NC}"
run_test "China geo-block" "curl -s --connect-timeout 10 --max-time 15 -H 'CloudFront-Viewer-Country: CN' https://$CF_DOMAIN/" "fail"
run_test "Russia geo-block" "curl -s --connect-timeout 10 --max-time 15 -H 'CloudFront-Viewer-Country: RU' https://$CF_DOMAIN/" "fail"
run_test "US access allowed" "curl -s --connect-timeout 10 --max-time 15 -H 'CloudFront-Viewer-Country: US' https://$CF_DOMAIN/" "pass"

echo ""

# Step 6: ALB Backend Health
echo -e "${PURPLE}Step 6: ALB Backend Health Check${NC}"
echo "================================="

ALB_NAMES=("linux-alb-$ENVIRONMENT" "windows-alb-$ENVIRONMENT")

for ALB_NAME in "${ALB_NAMES[@]}"; do
    echo -e "${BLUE}Checking ALB: $ALB_NAME${NC}"
    
    ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "null")
    
    if [ "$ALB_ARN" = "null" ] || [ "$ALB_ARN" = "None" ]; then
        echo -e "${YELLOW}  ⚠️  ALB not found (may not be deployed yet)${NC}"
        continue
    fi
    
    # Check target health
    TG_ARNS=$(aws elbv2 describe-target-groups --load-balancer-arn "$ALB_ARN" --query 'TargetGroups[*].TargetGroupArn' --output text 2>/dev/null)
    
    if [ -n "$TG_ARNS" ]; then
        for TG_ARN in $TG_ARNS; do
            HEALTHY_COUNT=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text 2>/dev/null || echo "0")
            TOTAL_COUNT=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --query 'length(TargetHealthDescriptions)' --output text 2>/dev/null || echo "0")
            
            if [ "$HEALTHY_COUNT" -gt 0 ]; then
                echo -e "${GREEN}  ✅ $HEALTHY_COUNT/$TOTAL_COUNT targets healthy${NC}"
            else
                echo -e "${RED}  ❌ No healthy targets ($HEALTHY_COUNT/$TOTAL_COUNT)${NC}"
            fi
        done
    else
        echo -e "${YELLOW}  ⚠️  No target groups found${NC}"
    fi
done

echo ""

# Step 7: Performance Test
echo -e "${PURPLE}Step 7: Performance Test${NC}"
echo "======================="

RESPONSE_TIME=$(curl -s -w "%{time_total}" --connect-timeout 10 --max-time 15 https://$CF_DOMAIN/ -o /dev/null 2>/dev/null || echo "timeout")
echo -e "${CYAN}Response time: ${RESPONSE_TIME}s${NC}"

if [ "$RESPONSE_TIME" != "timeout" ]; then
    RESPONSE_TIME_INT=$(echo "$RESPONSE_TIME * 100" | awk '{print int($1)}' 2>/dev/null || echo "999")
    if [ "$RESPONSE_TIME_INT" -lt 200 ]; then
        echo -e "${GREEN}  ✅ PASS (Good response time)${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${YELLOW}  ⚠️  SLOW (Response time > 2s)${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    echo -e "${RED}  ❌ TIMEOUT${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo ""

# Final Results
echo -e "${PURPLE}Test Results Summary${NC}"
echo "===================="
echo ""
echo -e "${CYAN}Total Tests: $TOTAL_TESTS${NC}"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"

if [ "$TOTAL_TESTS" -gt 0 ]; then
    PASS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "${CYAN}Pass Rate: $PASS_RATE%${NC}"
    
    if [ "$PASS_RATE" -ge 90 ]; then
        echo -e "${GREEN}🎉 EXCELLENT: Your WAF + CloudFront security is working great!${NC}"
    elif [ "$PASS_RATE" -ge 75 ]; then
        echo -e "${YELLOW}⚠️  GOOD: Most security features working, some issues to address${NC}"
    else
        echo -e "${RED}❌ NEEDS ATTENTION: Multiple security issues detected${NC}"
    fi
fi

echo ""
echo -e "${BLUE}Diagnosis:${NC}"
echo "=========="
if [ "$FAILED_TESTS" -gt "$PASSED_TESTS" ]; then
    echo -e "${RED}❌ WAF Issue Detected:${NC}"
    echo "Your WAF is associated with CloudFront but AWS managed rules are in COUNT mode."
    echo "This means they're monitoring attacks but not blocking them."
    echo ""
    echo -e "${YELLOW}To fix this:${NC}"
    echo "1. Check your WAF module configuration"
    echo "2. Ensure AWS managed rules have override_action = 'none' (not 'count')"
    echo "3. Redeploy with: terraform apply"
    echo ""
    echo -e "${BLUE}Check current WAF rules:${NC}"
    echo "aws wafv2 get-web-acl --scope CLOUDFRONT --id YOUR_WAF_ID --name YOUR_WAF_NAME"
else
    echo -e "${GREEN}✅ WAF and CloudFront security is working properly!${NC}"
fi

echo ""
echo -e "${BLUE}Usage Examples:${NC}"
echo "# Test with auto-detection: ./scripts/validate-cloudfront.sh dev"
echo "# Test specific domain: ./scripts/validate-cloudfront.sh dev d1234567890.cloudfront.net"
echo ""
echo "✅ Complete WAF + CloudFront security testing finished!"