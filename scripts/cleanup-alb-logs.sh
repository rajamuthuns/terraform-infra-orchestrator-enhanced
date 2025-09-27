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

# Function to check prerequisites and show account info
check_prerequisites() {
    print_color $BLUE "🔍 Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_color $RED "❌ Error: AWS CLI is not installed"
        exit 1
    fi
    
    # Check AWS credentials and show account info
    if ! aws sts get-caller-identity &> /dev/null; then
        print_color $RED "❌ Error: AWS CLI is not configured or credentials are invalid"
        exit 1
    fi
    
    # Display current AWS context
    print_color $BLUE "📋 Current AWS Context:"
    local account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "Unknown")
    local user_arn=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "Unknown")
    local region=$(aws configure get region 2>/dev/null || echo $AWS_DEFAULT_REGION || echo "us-east-1")
    
    echo "   Account ID: $account_id"
    echo "   User/Role: $user_arn"
    echo "   Region: $region"
    echo ""
    
    print_color $GREEN "✅ Prerequisites met"
}

# Function to find ALB access log buckets
find_alb_log_buckets() {
    local env=$1
    
    local found_buckets=()
    
    # Get all buckets as JSON and extract names properly
    local bucket_list=$(aws s3api list-buckets --query "Buckets[].Name" --output json 2>/dev/null || echo '[]')
    
    # Parse JSON and check each bucket
    while IFS= read -r bucket; do
        if [ -n "$bucket" ] && [ "$bucket" != "null" ]; then
            # Check if bucket matches ALB access log patterns for this environment
            # Pattern 1: Contains env, alb, and access-logs
            if [[ "$bucket" == *"$env"* ]] && [[ "$bucket" == *"alb"* ]] && [[ "$bucket" == *"access-logs"* ]]; then
                found_buckets+=("$bucket")
            # Pattern 2: Contains env, alb, and logs (broader match)
            elif [[ "$bucket" == *"$env"* ]] && [[ "$bucket" == *"alb"* ]] && [[ "$bucket" == *"log"* ]]; then
                found_buckets+=("$bucket")
            fi
        fi
    done < <(echo "$bucket_list" | jq -r '.[]?' 2>/dev/null || true)
    
    # Also check for specific known patterns that might be missed
    local specific_buckets=(
        "linux-alb-$env-linux-alb-$env-alb-access-logs"
        "windows-alb-$env-windows-alb-$env-alb-access-logs"
    )
    
    # Check if these specific buckets exist and add them if not already found
    for specific_bucket in "${specific_buckets[@]}"; do
        if aws s3api head-bucket --bucket "$specific_bucket" 2>/dev/null; then
            # Check if not already in found_buckets array
            if [[ ! " ${found_buckets[@]} " =~ " $specific_bucket " ]]; then
                found_buckets+=("$specific_bucket")
            fi
        fi
    done
    
    # Remove duplicates and return only bucket names (no colored output)
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
    
    # Use batch delete for efficiency - delete versions
    local delete_versions=$(echo "$versions" | jq -c '{Objects: [.Versions[]? | select(.Key != null) | {Key: .Key, VersionId: .VersionId}]}' 2>/dev/null || echo '{"Objects":[]}')
    if [ "$(echo "$delete_versions" | jq '.Objects | length')" -gt 0 ]; then
        echo "  Batch deleting $(echo "$delete_versions" | jq '.Objects | length') object versions..."
        aws s3api delete-objects --bucket "$bucket_name" --region "$bucket_region" --delete "$delete_versions" >/dev/null 2>&1 || true
    fi
    
    # Use batch delete for efficiency - delete markers
    local delete_markers=$(echo "$versions" | jq -c '{Objects: [.DeleteMarkers[]? | select(.Key != null) | {Key: .Key, VersionId: .VersionId}]}' 2>/dev/null || echo '{"Objects":[]}')
    if [ "$(echo "$delete_markers" | jq '.Objects | length')" -gt 0 ]; then
        echo "  Batch deleting $(echo "$delete_markers" | jq '.Objects | length') delete markers..."
        aws s3api delete-objects --bucket "$bucket_name" --region "$bucket_region" --delete "$delete_markers" >/dev/null 2>&1 || true
    fi
    
    # Delete any remaining objects (non-versioned)
    print_color $YELLOW "🧹 Removing any remaining objects..."
    aws s3 rm "s3://$bucket_name" --recursive --region "$bucket_region" >/dev/null 2>&1 || true
    
    # Additional aggressive cleanup if needed
    echo "  Final cleanup pass..."
    local remaining_versions=$(aws s3api list-object-versions --bucket "$bucket_name" --region "$bucket_region" --output json 2>/dev/null || echo '{}')
    local version_count=$(echo "$remaining_versions" | jq '.Versions | length' 2>/dev/null || echo "0")
    local marker_count=$(echo "$remaining_versions" | jq '.DeleteMarkers | length' 2>/dev/null || echo "0")
    
    if [ "$version_count" -gt 0 ] || [ "$marker_count" -gt 0 ]; then
        echo "  Found $version_count versions and $marker_count delete markers, cleaning up..."
        
        # One more batch delete attempt
        if [ "$version_count" -gt 0 ]; then
            local final_versions=$(echo "$remaining_versions" | jq -c '{Objects: [.Versions[]? | select(.Key != null) | {Key: .Key, VersionId: .VersionId}]}')
            aws s3api delete-objects --bucket "$bucket_name" --region "$bucket_region" --delete "$final_versions" >/dev/null 2>&1 || true
        fi
        
        if [ "$marker_count" -gt 0 ]; then
            local final_markers=$(echo "$remaining_versions" | jq -c '{Objects: [.DeleteMarkers[]? | select(.Key != null) | {Key: .Key, VersionId: .VersionId}]}')
            aws s3api delete-objects --bucket "$bucket_name" --region "$bucket_region" --delete "$final_markers" >/dev/null 2>&1 || true
        fi
    fi
    
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
    
    # Show current account context for debugging
    local current_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "Unknown")
    print_color $YELLOW "🏢 Running in AWS Account: $current_account"
    echo ""
    
    # Find ALB log buckets
    print_color $BLUE "🔍 Finding ALB access log buckets for environment: $env"
    
    # Show what specific buckets we're looking for
    print_color $YELLOW "🎯 Looking for bucket patterns:"
    echo "   - *$env*alb*access-logs*"
    echo "   - *$env*alb*log*"
    echo "   - linux-alb-$env-linux-alb-$env-alb-access-logs"
    echo "   - windows-alb-$env-windows-alb-$env-alb-access-logs"
    echo ""
    
    local buckets=($(find_alb_log_buckets "$env"))
    
    if [ ${#buckets[@]} -eq 0 ]; then
        print_color $YELLOW "⚠️  No ALB access log buckets found for environment: $env"
        print_color $BLUE "🔍 Debug: Showing all S3 buckets in current account for reference:"
        aws s3 ls | head -10 | while read -r line; do
            echo "   $line"
        done
        local total_buckets=$(aws s3 ls | wc -l)
        if [ "$total_buckets" -gt 10 ]; then
            echo "   ... and $((total_buckets - 10)) more buckets"
        fi
        echo ""
        print_color $BLUE "ℹ️  This might mean:"
        echo "  - ALB access logging is not enabled"
        echo "  - Buckets use different naming convention"
        echo "  - Buckets are in different AWS account/region"
        echo "  - Script is running in wrong AWS account"
        return 0
    fi
    
    print_color $BLUE "🎯 Found ALB access log buckets:"
    for bucket in "${buckets[@]}"; do
        echo "  - $bucket"
        print_color $YELLOW "  Found: $bucket"
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