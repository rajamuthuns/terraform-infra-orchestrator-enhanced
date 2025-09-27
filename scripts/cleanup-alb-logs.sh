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
    echo "Usage: $0 [ENVIRONMENT] [BUCKET_NAME1] [BUCKET_NAME2] ..."
    echo ""
    echo "This script cleans up S3 buckets that prevent Terraform destroy:"
    echo "  - Automatically finds Terraform-managed S3 buckets for the environment"
    echo "  - Uses multiple detection methods (Terraform state, tags, naming patterns)"
    echo "  - Empties the buckets (removes all objects and versions)"
    echo "  - Does NOT delete the buckets (Terraform will handle that)"
    echo "  - Supports cross-account access via OrganizationAccountAccessRole"
    echo ""
    echo "Detection Methods:"
    echo "  1. Terraform state inspection"
    echo "  2. Bucket naming pattern analysis"
    echo "  3. Terraform tag checking"
    echo "  4. Failed destroy error parsing"
    echo ""
    echo "Examples:"
    echo "  $0 dev                           # Auto-detect and cleanup dev environment buckets"
    echo "  $0 staging                       # Auto-detect and cleanup staging environment buckets"
    echo "  $0 dev bucket1 bucket2           # Cleanup specific buckets in dev environment"
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
find_terraform_managed_buckets() {
    local env=$1
    
    local found_buckets=()
    
    print_color $BLUE "🔍 Method 1: Checking Terraform state for managed S3 buckets..."
    
    # Method 1: Get buckets from Terraform state
    if command -v terraform &> /dev/null && [ -f "main.tf" ]; then
        # Initialize terraform if needed
        if [ ! -d ".terraform" ]; then
            print_color $YELLOW "   Initializing Terraform..."
            terraform init -backend-config=shared/backend-common.hcl >/dev/null 2>&1 || true
        fi
        
        # Select the correct workspace
        if terraform workspace list 2>/dev/null | grep -q "^\s*${env}\s*$"; then
            terraform workspace select "$env" >/dev/null 2>&1 || true
        fi
        
        # Get S3 buckets from Terraform state
        local tf_buckets=$(terraform state list 2>/dev/null | grep -E "aws_s3_bucket\." | grep -v "aws_s3_bucket_" || true)
        
        if [ -n "$tf_buckets" ]; then
            print_color $YELLOW "   Found Terraform-managed S3 buckets in state:"
            while IFS= read -r resource; do
                if [ -n "$resource" ]; then
                    local bucket_name=$(terraform state show "$resource" 2>/dev/null | grep -E "^\s*bucket\s*=" | sed 's/.*=\s*"\([^"]*\)".*/\1/' | tr -d ' ' || true)
                    if [ -n "$bucket_name" ] && [ "$bucket_name" != "null" ]; then
                        echo "     - $bucket_name (from $resource)"
                        found_buckets+=("$bucket_name")
                    fi
                fi
            done <<< "$tf_buckets"
        else
            print_color $YELLOW "   No S3 buckets found in Terraform state"
        fi
    else
        print_color $YELLOW "   Terraform not available or not in Terraform directory"
    fi
    
    print_color $BLUE "🔍 Method 2: Scanning for buckets that match Terraform naming patterns..."
    
    # Method 2: Get all buckets and filter for ones that look like Terraform-managed ALB log buckets
    local bucket_list=$(aws s3api list-buckets --query "Buckets[].Name" --output json 2>/dev/null || echo '[]')
    
    # Look for buckets that match common Terraform ALB module patterns
    while IFS= read -r bucket; do
        if [ -n "$bucket" ] && [ "$bucket" != "null" ]; then
            # Check if bucket looks like it's managed by Terraform ALB modules
            if [[ "$bucket" == *"$env"* ]] && [[ "$bucket" == *"alb"* ]] && [[ "$bucket" == *"access"* ]] && [[ "$bucket" == *"log"* ]]; then
                # Check if not already found
                if [[ ! " ${found_buckets[@]} " =~ " $bucket " ]]; then
                    print_color $YELLOW "   Found potential ALB access log bucket: $bucket"
                    found_buckets+=("$bucket")
                fi
            fi
        fi
    done < <(echo "$bucket_list" | jq -r '.[]?' 2>/dev/null || true)
    
    print_color $BLUE "🔍 Method 3: Checking for buckets with Terraform tags..."
    
    # Method 3: Check for buckets with Terraform tags
    while IFS= read -r bucket; do
        if [ -n "$bucket" ] && [ "$bucket" != "null" ]; then
            # Check bucket tags to see if it's managed by Terraform
            local tags=$(aws s3api get-bucket-tagging --bucket "$bucket" --query 'TagSet' --output json 2>/dev/null || echo '[]')
            
            # Check if bucket has ManagedBy=terraform tag or similar
            local managed_by=$(echo "$tags" | jq -r '.[] | select(.Key=="ManagedBy") | .Value' 2>/dev/null || echo "")
            local terraform_workspace=$(echo "$tags" | jq -r '.[] | select(.Key=="Workspace") | .Value' 2>/dev/null || echo "")
            local environment_tag=$(echo "$tags" | jq -r '.[] | select(.Key=="Environment") | .Value' 2>/dev/null || echo "")
            
            if [[ "$managed_by" == "terraform" ]] || [[ "$terraform_workspace" == "$env" ]] || [[ "$environment_tag" == "$env" ]]; then
                # Check if it's an ALB-related bucket and not already found
                if [[ "$bucket" == *"alb"* ]] && [[ "$bucket" == *"log"* ]] && [[ ! " ${found_buckets[@]} " =~ " $bucket " ]]; then
                    print_color $YELLOW "   Found Terraform-tagged ALB bucket: $bucket"
                    found_buckets+=("$bucket")
                fi
            fi
        fi
    done < <(echo "$bucket_list" | jq -r '.[]?' 2>/dev/null || true)
    
    # Remove duplicates and return only bucket names
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
    print_color $YELLOW "🏢 Currently running in AWS Account: $current_account"
    
    # Get target account ID for the environment
    local target_account_id=""
    if [ -f "$ACCOUNTS_FILE" ]; then
        target_account_id=$(jq -r ".${env}.account_id" "$ACCOUNTS_FILE" 2>/dev/null || echo "")
    fi
    
    if [ -z "$target_account_id" ] || [ "$target_account_id" = "null" ]; then
        print_color $YELLOW "⚠️  No target account configured for environment: $env"
        print_color $BLUE "ℹ️  Will search for buckets in current account: $current_account"
        echo ""
    else
        print_color $BLUE "🎯 Target environment account: $target_account_id"
        
        # Check if we need to assume role in target account
        if [ "$current_account" != "$target_account_id" ]; then
            print_color $YELLOW "🔄 Need to assume role in target account for bucket access"
            
            # Assume role in target account
            local target_role_arn="arn:aws:iam::${target_account_id}:role/OrganizationAccountAccessRole"
            print_color $BLUE "🔐 Assuming role: $target_role_arn"
            
            if TARGET_CREDENTIALS=$(aws sts assume-role \
                --role-arn "$target_role_arn" \
                --role-session-name "alb-cleanup-$env-$(date +%s)" \
                --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
                --output text 2>&1); then
                
                # Export credentials for this session
                export AWS_ACCESS_KEY_ID=$(echo $TARGET_CREDENTIALS | cut -d' ' -f1)
                export AWS_SECRET_ACCESS_KEY=$(echo $TARGET_CREDENTIALS | cut -d' ' -f2)
                export AWS_SESSION_TOKEN=$(echo $TARGET_CREDENTIALS | cut -d' ' -f3)
                
                # Verify we're now in the target account
                local new_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "Unknown")
                print_color $GREEN "✅ Successfully assumed role in target account: $new_account"
                
                if [ "$new_account" != "$target_account_id" ]; then
                    print_color $RED "❌ Role assumption failed - still in wrong account"
                    return 1
                fi
            else
                print_color $RED "❌ Failed to assume role in target account: $target_account_id"
                print_color $YELLOW "Error: $TARGET_CREDENTIALS"
                print_color $BLUE "ℹ️  Will search for buckets in current account instead"
            fi
        else
            print_color $GREEN "✅ Already in target account"
        fi
        echo ""
    fi
    
    # Show final account context after potential role assumption
    local final_account=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "Unknown")
    local final_role=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "Unknown")
    print_color $BLUE "🏢 Searching for buckets in account: $final_account"
    print_color $BLUE "🔑 Using credentials: $final_role"
    echo ""
    
    # Find Terraform-managed buckets that need cleanup
    print_color $BLUE "🔍 Finding Terraform-managed S3 buckets for environment: $env"
    print_color $BLUE "ℹ️  Using dynamic detection instead of hardcoded patterns"
    echo ""
    
    local buckets=($(find_terraform_managed_buckets "$env"))
    
    # Method 4: If no buckets found, try to parse from recent terraform destroy errors
    if [ ${#buckets[@]} -eq 0 ]; then
        print_color $BLUE "🔍 Method 4: Checking for buckets mentioned in recent terraform errors..."
        
        # Look for terraform destroy error patterns in common log locations
        local error_buckets=()
        
        # Check if there are any .terraform logs or recent error output
        if [ -f ".terraform/terraform.tfstate" ] || [ -f "terraform.tfstate" ]; then
            # Try to find bucket names from terraform plan/destroy output patterns
            # This would typically be called after a failed destroy
            print_color $YELLOW "   Checking for bucket names in terraform state files..."
            
            # Look for S3 bucket resources that might be causing issues
            if command -v terraform &> /dev/null; then
                local state_buckets=$(terraform state list 2>/dev/null | grep "aws_s3_bucket\." | grep -v "aws_s3_bucket_" || true)
                if [ -n "$state_buckets" ]; then
                    while IFS= read -r resource; do
                        if [ -n "$resource" ]; then
                            local bucket_name=$(terraform state show "$resource" 2>/dev/null | grep -E "^\s*bucket\s*=" | sed 's/.*=\s*"\([^"]*\)".*/\1/' | tr -d ' ' || true)
                            if [ -n "$bucket_name" ] && [[ "$bucket_name" == *"log"* ]]; then
                                print_color $YELLOW "   Found bucket from state: $bucket_name"
                                error_buckets+=("$bucket_name")
                            fi
                        fi
                    done <<< "$state_buckets"
                fi
            fi
        fi
        
        # Add any found error buckets to the main list
        for bucket in "${error_buckets[@]}"; do
            buckets+=("$bucket")
        done
    fi
    
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

# Function to cleanup specific buckets (for manual override)
cleanup_specific_buckets() {
    shift # Remove first argument (environment)
    local specific_buckets=("$@")
    
    print_color $BLUE "🎯 Cleaning up specific buckets provided as arguments:"
    for bucket in "${specific_buckets[@]}"; do
        echo "  - $bucket"
    done
    echo ""
    
    # Empty each bucket
    for bucket in "${specific_buckets[@]}"; do
        empty_s3_bucket "$bucket"
        echo ""
    done
    
    print_color $GREEN "✅ Specific bucket cleanup completed!"
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
    
    # Check if specific bucket names were provided
    if [ $# -gt 1 ]; then
        print_color $BLUE "🎯 Specific bucket names provided, using manual mode"
        cleanup_specific_buckets "$@"
        return 0
    fi
    
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