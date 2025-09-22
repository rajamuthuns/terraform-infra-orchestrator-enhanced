#!/bin/bash

# Create GitOps branches for the workflow
# This script creates the required dev, staging, and production branches

set -e

echo "🚀 Creating GitOps branches..."

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# Function to create and push branch
create_branch() {
    local branch_name=$1
    echo "Creating branch: $branch_name"
    
    if git show-ref --verify --quiet refs/heads/$branch_name; then
        echo "⚠️  Branch $branch_name already exists locally"
    else
        git checkout -b $branch_name
        echo "✅ Created local branch: $branch_name"
    fi
    
    # Push to remote
    if git ls-remote --heads origin $branch_name | grep -q $branch_name; then
        echo "⚠️  Branch $branch_name already exists on remote"
    else
        git push -u origin $branch_name
        echo "✅ Pushed branch to remote: $branch_name"
    fi
}

# Create branches in order
echo ""
echo "Creating dev branch..."
create_branch "dev"

echo ""
echo "Creating staging branch..."
create_branch "staging"

echo ""
echo "Creating production branch..."
create_branch "production"

# Return to original branch
echo ""
echo "Returning to original branch: $CURRENT_BRANCH"
git checkout $CURRENT_BRANCH

echo ""
echo "🎉 GitOps branches created successfully!"
echo ""
echo "Branches created:"
echo "  - dev (for development work)"
echo "  - staging (for staging deployments)"  
echo "  - production (for production deployments)"
echo ""
echo "Next steps:"
echo "1. Run: ./scripts/setup-branch-protection.sh"
echo "2. Run: ./scripts/setup-github-environments.sh"
echo "3. Configure GitHub secrets (see docs/GITOPS_SETUP.md)"
echo "4. Start developing on the dev branch!"