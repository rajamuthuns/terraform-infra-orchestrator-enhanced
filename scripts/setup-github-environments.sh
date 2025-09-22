#!/bin/bash

# Setup GitHub Environments for GitOps workflow
# This script creates the required GitHub environments with appropriate protection rules

set -e

REPO_OWNER="${1:-$(gh repo view --json owner --jq .owner.login)}"
REPO_NAME="${2:-$(gh repo view --json name --jq .name)}"

echo "Setting up GitHub environments for $REPO_OWNER/$REPO_NAME"

# Function to create environment
create_environment() {
    local env_name=$1
    local require_reviewers=$2
    local reviewers=$3
    
    echo "Creating environment: $env_name"
    
    # Create the environment
    gh api \
        --method PUT \
        -H "Accept: application/vnd.github+json" \
        "/repos/$REPO_OWNER/$REPO_NAME/environments/$env_name" \
        -f wait_timer=0 \
        -f prevent_self_review=true \
        -f deployment_branch_policy='{"protected_branches":false,"custom_branch_policies":true}'
    
    if [ "$require_reviewers" = "true" ] && [ -n "$reviewers" ]; then
        # Add required reviewers
        gh api \
            --method PUT \
            -H "Accept: application/vnd.github+json" \
            "/repos/$REPO_OWNER/$REPO_NAME/environments/$env_name" \
            -f reviewers="$reviewers"
    fi
    
    echo "✅ Environment $env_name created"
}

# Create environments
echo "Creating dev environment (no protection)..."
create_environment "dev" "false" ""

echo "Creating staging environment (require reviewers)..."
create_environment "staging" "true" '[{"type":"User","id":null}]'

echo "Creating production environment (require reviewers)..."
create_environment "prod" "true" '[{"type":"User","id":null}]'

echo "🎉 GitHub environments setup complete!"
echo ""
echo "Manual steps required:"
echo "1. Go to Settings > Environments in your GitHub repo"
echo "2. Configure reviewers for staging and prod environments"
echo "3. Set up required secrets: PRIVATE_REPO_TOKEN, AWS credentials"