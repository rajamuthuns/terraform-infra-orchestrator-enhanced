#!/bin/bash

# Create the GitOps workflow branches
set -e

echo "Creating GitOps workflow branches..."

# Create and push dev branch
git checkout -b dev 2>/dev/null || git checkout dev
git push -u origin dev

# Create and push staging branch  
git checkout -b staging 2>/dev/null || git checkout staging
git push -u origin staging

# Create and push production branch
git checkout -b production 2>/dev/null || git checkout production  
git push -u origin production

# Return to main branch
git checkout main

echo "✅ Branches created: dev, staging, production"
echo ""
echo "Manual branch protection setup (GitHub web interface):"
echo "1. Go to: https://github.com/$(gh repo view --json owner --jq -r .owner.login)/$(gh repo view --json name --jq -r .name)/settings/branches"
echo "2. For each branch (dev, staging, production):"
echo "   - Click 'Add rule'"
echo "   - Branch name pattern: exact branch name"
echo "   - Check 'Require a pull request before merging'"
echo "   - For staging: Require 1 approval"
echo "   - For production: Require 2 approvals"
echo "   - Check 'Dismiss stale PR reviews when new commits are pushed'"