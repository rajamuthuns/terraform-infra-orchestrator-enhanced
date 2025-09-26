#!/bin/bash

# Force Empty S3 Buckets Script
# This script forcefully empties S3 buckets that are preventing Terraform destroy
# Usage: ./force-empty-s3-buckets.sh [BUCKET_NAME1] [BUCKET_NAME2] ...
# Or: ./force-empty-s3-buckets.sh --auto-detect [ENVIRONMENT]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to forcefully empty an S3 bucket
force_empty_bucket() {
    local bucket_name=$1
    
    print_color $BLUE "🧹 Force emptying S3 bucket: $bucket_name"
    
    # Check if bucket exists
    if ! aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        print_color $GREEN "✅ Bucket $bucket_name does not exist"
        return 0
    fi
    
    # Get bucket region
    local bucket_region=$(aws s3api get-bucket-location --bucket "$bucket_name" --query 'LocationConstraint' --output text 2>/dev/null || echo "us-east-1")
    if [ "$bucket_region" = "None" ] || [ "$bucket_region" = "null" ]; then
        bucket_region="us-east-1"
    fi
    
    print_color $YELLOW "📋 Bucket region: $bucket_region"
    
    # Method 1: Use AWS CLI to remove all objects and versions
    print_color $YELLOW "🗑️  Removing all objects and versions..."
    aws s3api delete-objects --bucket "$bucket_name" --region "$bucket_region" \
        --delete "$(aws s3api list-object-versions --bucket "$bucket_name" --region "$bucket_region" \
        --output json --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || true
    
    # Method 2: Remove delete markers
    print_color $YELLOW "🗑️  Removing delete markers..."
    aws s3api delete-objects --bucket "$bucket_name" --region "$bucket_region" \
        --delete "$(aws s3api list-object-versions --bucket "$bucket_name" --region "$bucket_region" \
        --output json --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || true
    
    # Method 3: Force remove with s3 rm (for any remaining objects)
    print_color $YELLOW "🗑️  Force removing any remaining objects..."
    aws s3 rm "s3://$bucket_name" --recursive --region "$bucket_region" 2>/dev/null || true
    
    # Method 4: Use lifecycle policy to expire objects (if needed)
    print_color $YELLOW "⏰ Setting lifecycle policy to expire objects immediately..."
    aws s3api put-bucket-lifecycle-configuration --bucket "$bucket_name" --region "$bucket_region" \
        --lifecycle-configuration '{
            "Rules": [
                {
                    "ID": "ForceDeleteRule",
                    "Status": "Enabled",
                    "Filter": {},
                    "Expiration": {
                        "Days": 1
                    },
                    "NoncurrentVersionExpiration": {
                        "NoncurrentDays": 1
                    },
                    "AbortIncompleteMultipartUpload": {
                        "DaysAfterInitiation": 1
                    }
                }
            ]
        }' 2>/dev/null || true
    
    # Wait a moment for lifecycle to take effect
    sleep 2
    
    # Final cleanup attempt
    print_color $YELLOW "🧹 Final cleanup attempt..."
    aws s3 rm "s3://$bucket_name" --recursive --region "$bucket_region" 2>/dev/null || true
    
    # Verify bucket is empty
    local object_count=$(aws s3 ls "s3://$bucket_name" --recursive --region "$bucket_region" 2>/dev/null | wc -l || echo "0")
    
    if [ "$object_count" -eq 0 ]; then
        print_color $GREEN "✅ Successfully emptied bucket: $bucket_name"
    else
        print_color $YELLOW "⚠️  Bucket may still contain $object_count objects: $bucket_name"
        print_color $BLUE "💡 Try running terraform destroy again - some objects may be access logs still being written"
    fi
}

# Function to auto-detect ALB log buckets
auto_detect_buckets() {
    local env=$1
    
    print_color $BLUE "🔍 Auto-detecting ALB log buckets for environment: $env"
    
    # Get all buckets and filter for ALB access log patterns
    local buckets=($(aws s3api list-buckets --query "Buckets[].Name" --output text | tr '\t' '\n' | grep -E ".*alb.*$env.*log.*|.*$env.*alb.*log.*" || true))
    
    # Also check for the specific buckets mentioned in your error
    local specific_buckets=(
        "windows-alb-$env-windows-alb-$env-alb-access-logs"
        "linux-alb-$env-linux-alb-$env-alb-access-logs"
    )
    
    for bucket in "${specific_buckets[@]}"; do
        if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
            buckets+=("$bucket")
        fi
    done
    
    # Remove duplicates
    buckets=($(printf '%s\n' "${buckets[@]}" | sort -u))
    
    if [ ${#buckets[@]} -eq 0 ]; then
        print_color $YELLOW "⚠️  No ALB log buckets found for environment: $env"
        return 1
    fi
    
    print_color $GREEN "✅ Found ALB log buckets:"
    for bucket in "${buckets[@]}"; do
        echo "  - $bucket"
    done
    
    # Empty each bucket
    for bucket in "${buckets[@]}"; do
        force_empty_bucket "$bucket"
        echo ""
    done
}

# Main function
main() {
    print_color $BLUE "🧹 Force Empty S3 Buckets"
    print_color $BLUE "========================="
    echo ""
    
    if [ $# -eq 0 ]; then
        print_color $RED "❌ Error: No arguments provided"
        echo ""
        echo "Usage:"
        echo "  $0 BUCKET_NAME1 [BUCKET_NAME2] ...    # Empty specific buckets"
        echo "  $0 --auto-detect ENVIRONMENT          # Auto-detect and empty ALB log buckets"
        echo ""
        echo "Examples:"
        echo "  $0 windows-alb-dev-windows-alb-dev-alb-access-logs"
        echo "  $0 --auto-detect dev"
        exit 1
    fi
    
    if [ "$1" = "--auto-detect" ]; then
        if [ -z "$2" ]; then
            print_color $RED "❌ Error: Environment required for auto-detect"
            exit 1
        fi
        auto_detect_buckets "$2"
    else
        # Empty specific buckets
        for bucket in "$@"; do
            force_empty_bucket "$bucket"
            echo ""
        done
    fi
    
    print_color $GREEN "✅ Bucket cleanup completed!"
    print_color $BLUE "🔄 You can now run terraform destroy again"
}

# Run main function
main "$@"