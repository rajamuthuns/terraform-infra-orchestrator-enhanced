#!/bin/bash

# Setup branch protection rules for GitOps workflow
# This script configures GitHub branch protection via GitHub CLI

set -e

REPO_OWNER="${1:-$(gh repo view --json owner --jq .owner.login)}"
REPO_NAME="${2:-$(gh repo view --json name --jq .name)}"

echo "Setting up branch protection for $REPO_OWNER/$REPO_NAME"

# Function to setup branch protection
setup_branch_protection() {
    local branch=$1
    local require_reviews=$2
    local required_reviewers=$3
    
    echo "Configuring protection for branch: $branch"
    
    if [ "$require_reviews" = "true" ]; then
        MSYS_NO_PATHCONV=1 gh api \
            --method PUT \
            -H "Accept: application/vnd.github+json" \
            "/repos/$REPO_OWNER/$REPO_NAME/branches/$branch/protection" \
            -f required_status_checks='{"strict":true,"contexts":["Terraform Pipeline"]}' \
            -f enforce_admins=true \
            -f required_pull_request_reviews="{\"required_approving_review_count\":$required_reviewers,\"dismiss_stale_reviews\":true,\"require_code_owner_reviews\":false}" \
            -f restrictions=null
    else
        # For dev branch - minimal protection
        MSYS_NO_PATHCONV=1 gh api \
            --method PUT \
            -H "Accept: application/vnd.github+json" \
            "/repos/$REPO_OWNER/$REPO_NAME/branches/$branch/protection" \
            -f required_status_checks='{"strict":false,"contexts":[]}' \
            -f enforce_admins=false \
            -f required_pull_request_reviews=null \
            -f restrictions=null
    fi
    
    echo "✅ Branch protection configured for $branch"
}

# Setup protection for each branch
echo "Setting up dev branch (minimal protection)..."
setup_branch_protection "dev" "false" "0"

echo "Setting up staging branch (require 1 review)..."
setup_branch_protection "staging" "true" "1"

echo "Setting up production branch (require 2 reviews)..."
setup_branch_protection "production" "true" "2"

echo "🎉 Branch protection setup complete!"
echo ""
echo "Next steps:"
echo "1. Set up GitHub secrets: DEFAULT_REVIEWERS, PRODUCTION_APPROVERS"
echo "2. Create the three branches: dev, staging, production"
echo "3. Test the workflow by pushing to dev branch"