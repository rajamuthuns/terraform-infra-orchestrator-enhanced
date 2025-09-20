#!/bin/bash

# ALB Access Log Bucket Cleanup Script
# This script cleans up ALB access log buckets that prevent Terraform destroy
# Usage: ./cleanup-alb-logs.sh [ENVIRONMENT]

set -e

# Configuration
ACCOUNTS_FILE="config/aws-accounts.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to display usage
usage() {
    print_color $BLUE "ALB Access Log Bucket Cleanup Script"
    echo ""
    echo "Usage: $0 [ENVIRONMENT]"
    echo ""
    echo "This script cleans up ALB access log buckets that prevent Terraform destroy:"
    echo "  - Finds ALB access log buckets for the environment"
    echo "  - Empties the buckets (removes all log files)"
    echo "  - Does NOT delete the buckets (Terraform will handle that)"
    echo "  - Preserves Terraform state and DynamoDB tables"
    echo ""
    echo "Examples:"
    echo "  $0 dev      # Cleanup dev environment ALB log buckets"
    echo "  $0 staging  # Cleanup staging environment ALB log buckets"
    echo "  $0 prod     # Cleanup production environment ALB log buckets"
    echo ""
    exit 1
}

# Function to check prerequisites
check_prerequisites() {
    print_color $BLUE "🔍 Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_color $RED "❌ Error: AWS CLI is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_color $RED "❌ Error: AWS CLI is not configured or credentials are invalid"
        exit 1
    fi
    
    print_color $GREEN "✅ Prerequisites met"
}

# Function to find ALB access log buckets
find_alb_log_buckets() {
    local env=$1
    
    print_color $BLUE "🔍 Finding ALB access log buckets for environment: $env"
    
    # Common ALB log bucket naming patterns
    local bucket_patterns=(
        "*alb*access*log*${env}*"
        "*${env}*alb*access*log*"
        "*alb*log*${env}*"
        "*${env}*alb*log*"
        "*access*log*${env}*"
        "*${env}*access*log*"
    )
    
    local found_buckets=()
    
    # Search for buckets matching ALB log patterns
    for pattern in "${bucket_patterns[@]}"; do
        local buckets=$(aws s3api list-buckets --query "Buckets[?contains(Name, '${env}') && (contains(Name, 'alb') || contains(Name, 'access') || contains(Name, 'log'))].Name" --output text 2>/dev/null || true)
        
        if [ -n "$buckets" ]; then
            for bucket in $buckets; do
                # Check if bucket is used for ALB access logs
                local bucket_policy=$(aws s3api get-bucket-policy --bucket "$bucket" --query 'Policy' --output text 2>/dev/null || echo "")
                local bucket_logging=$(aws s3api get-bucket-logging --bucket "$bucket" 2>/dev/null || echo "")
                
                # Check if bucket has ALB-related tags or policies
                if [[ "$bucket_policy" == *"elasticloadbalancing"* ]] || [[ "$bucket" == *"alb"* ]] || [[ "$bucket" == *"access-log"* ]]; then
                    found_buckets+=("$bucket")
                fi
            done
        fi
    done
    
    # Also check for buckets created by Terraform ALB module
    local tf_alb_buckets=$(aws s3api list-buckets --query "Buckets[?contains(Name, '${env}') && contains(Name, 'alb')].Name" --output text 2>/dev/null || true)
    if [ -n "$tf_alb_buckets" ]; then
        for bucket in $tf_alb_buckets; do
            if [[ ! " ${found_buckets[@]} " =~ " ${bucket} " ]]; then
                found_buckets+=("$bucket")
            fi
        done
    fi
    
    # Remove duplicates and return
    printf '%s\n' "${found_buckets[@]}" | sort -u
}

# Function to empty S3 bucket (but not delete it)
empty_s3_bucket() {
    local bucket_name=$1
    
    print_color $BLUE "🧹 Emptying S3 bucket: $bucket_name"
    
    # Check if bucket exists
    if ! aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        print_color $GREEN "✅ Bucket $bucket_name does not exist"
        return 0
    fi
    
    # Get bucket location for proper region handling
    local bucket_region=$(aws s3api get-bucket-location --bucket "$bucket_name" --query 'LocationConstraint' --output text 2>/dev/null || echo "us-east-1")
    if [ "$bucket_region" = "None" ] || [ "$bucket_region" = "null" ]; then
        bucket_region="us-east-1"
    fi
    
    print_color $YELLOW "📋 Removing all objects from bucket (region: $bucket_region)..."
    
    # Delete all object versions and delete markers
    local versions=$(aws s3api list-object-versions --bucket "$bucket_name" --region "$bucket_region" --output json 2>/dev/null || echo '{}')
    
    # Process versions
    echo "$versions" | jq -r '.Versions[]? | select(.Key != null) | "\(.Key)\t\(.VersionId)"' | \
    while IFS=$'\t' read -r key version_id; do
        if [ -n "$key" ] && [ -n "$version_id" ]; then
            echo "  Deleting version: $key ($version_id)"
            aws s3api delete-object --bucket "$bucket_name" --key "$key" --version-id "$version_id" --region "$bucket_region" >/dev/null 2>&1 || true
        fi
    done
    
    # Process delete markers
    echo "$versions" | jq -r '.DeleteMarkers[]? | select(.Key != null) | "\(.Key)\t\(.VersionId)"' | \
    while IFS=$'\t' read -r key version_id; do
        if [ -n "$key" ] && [ -n "$version_id" ]; then
            echo "  Deleting delete marker: $key ($version_id)"
            aws s3api delete-object --bucket "$bucket_name" --key "$key" --version-id "$version_id" --region "$bucket_region" >/dev/null 2>&1 || true
        fi
    done
    
    # Delete any remaining objects (non-versioned)
    print_color $YELLOW "🧹 Removing any remaining objects..."
    aws s3 rm "s3://$bucket_name" --recursive --region "$bucket_region" >/dev/null 2>&1 || true
    
    # Verify bucket is empty
    local object_count=$(aws s3 ls "s3://$bucket_name" --recursive --region "$bucket_region" 2>/dev/null | wc -l || echo "0")
    
    if [ "$object_count" -eq 0 ]; then
        print_color $GREEN "✅ Successfully emptied bucket: $bucket_name"
    else
        print_color $YELLOW "⚠️  Bucket may still contain some objects: $bucket_name"
        print_color $YELLOW "    This is normal for ALB logs as new logs may be written during cleanup"
    fi
}

# Function to cleanup ALB log buckets for environment
cleanup_alb_logs() {
    local env=$1
    
    print_color $BLUE "🧹 Starting ALB log cleanup for environment: $env"
    echo ""
    
    # Find ALB log buckets
    local buckets=($(find_alb_log_buckets "$env"))
    
    if [ ${#buckets[@]} -eq 0 ]; then
        print_color $GREEN "✅ No ALB access log buckets found for environment: $env"
        print_color $BLUE "ℹ️  This might mean:"
        echo "  - ALB access logging is not enabled"
        echo "  - Buckets use different naming convention"
        echo "  - Buckets are in different AWS account/region"
        return 0
    fi
    
    print_color $BLUE "🎯 Found ALB access log buckets:"
    for bucket in "${buckets[@]}"; do
        echo "  - $bucket"
    done
    echo ""
    
    print_color $YELLOW "ℹ️  This will empty the buckets but NOT delete them"
    print_color $YELLOW "ℹ️  Terraform will handle bucket deletion after they are empty"
    echo ""
    
    # Empty each bucket
    for bucket in "${buckets[@]}"; do
        empty_s3_bucket "$bucket"
        echo ""
    done
    
    print_color $GREEN "✅ ALB log cleanup completed for environment: $env"
    print_color $BLUE "📋 Summary:"
    for bucket in "${buckets[@]}"; do
        echo "  ✅ Emptied: $bucket"
    done
    echo ""
    print_color $BLUE "🔄 Terraform destroy should now succeed"
}

# Main script
main() {
    local environment=$1
    
    print_color $BLUE "🧹 ALB Access Log Bucket Cleanup"
    print_color $BLUE "================================"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    echo ""
    
    # Validate environment parameter
    if [ -z "$environment" ]; then
        print_color $RED "❌ Error: Environment parameter is required"
        echo ""
        usage
    fi
    
    case "$environment" in
        dev|staging|prod)
            cleanup_alb_logs "$environment"
            ;;
        *)
            print_color $RED "❌ Error: Invalid environment '$environment'"
            echo ""
            usage
            ;;
    esac
}

# Handle command line arguments
case "$1" in
    -h|--help)
        usage
        ;;
    *)
        main "$1"
        ;;
esac