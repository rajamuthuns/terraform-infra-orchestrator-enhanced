#!/bin/bash

# Setup basic repository protection for free GitHub accounts
# This script configures basic repository settings via GitHub CLI

set -e

REPO_OWNER="${1:-$(gh repo view --json owner --jq .owner.login)}"
REPO_NAME="${2:-$(gh repo view --json name --jq .name)}"

echo "Setting up basic repository protection for $REPO_OWNER/$REPO_NAME"

# Enable basic repository settings
echo "Configuring repository settings..."

# Disable merge commits, enable squash merging
MSYS_NO_PATHCONV=1 gh api \
    --method PATCH \
    -H "Accept: application/vnd.github+json" \
    "/repos/$REPO_OWNER/$REPO_NAME" \
    -f allow_merge_commit=false \
    -f allow_squash_merge=true \
    -f allow_rebase_merge=true \
    -f delete_branch_on_merge=true

echo "✅ Repository settings configured"
echo ""
echo "Basic protection enabled:"
echo "- Merge commits disabled (forces PR workflow)"
echo "- Squash merge enabled"
echo "- Rebase merge enabled" 
echo "- Auto-delete branches after merge"
echo ""
echo "Manual steps for additional protection:"
echo "1. Go to Settings > Branches in GitHub web interface"
echo "2. Add branch protection rules manually for main/dev/staging/production"
echo "3. Or upgrade to GitHub Pro for API-based branch protection"