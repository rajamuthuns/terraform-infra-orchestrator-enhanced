# Manual Workflow Test Guide

## 🔧 Fixed Issues:

### 1. **PR Creation Logic Simplified:**
- ❌ **Before**: Complex branch creation and merging logic
- ✅ **After**: Direct PR creation from source branch to target branch
- ✅ **Result**: Creates PR directly from `dev` → `staging` or `staging` → `production`

### 2. **YAML Syntax Cleaned:**
- ❌ **Before**: Extra blank lines in YAML
- ✅ **After**: Clean YAML syntax
- ✅ **Result**: Manual trigger should now appear in Actions tab

## 🚀 How to Test Manual Workflow:

### Step 1: Check if Manual Trigger Appears
1. Go to your GitHub repository
2. Click **Actions** tab
3. Look for **"Terraform Infrastructure Deploy"** workflow
4. Click on it
5. You should see **"Run workflow"** button on the right

### Step 2: Test Manual Trigger
1. Click **"Run workflow"**
2. Select options:
   - **Branch**: `dev`
   - **Environment**: `dev`
   - **Action**: `setup-only` (safe test)
   - **Skip setup**: `false`
   - **Create Promotion PR**: `false` (for initial test)
3. Click **"Run workflow"**

### Step 3: Test PR Creation
After successful dev deployment:
1. Run workflow again with:
   - **Branch**: `dev`
   - **Environment**: `dev`
   - **Action**: `plan-and-apply`
   - **Create Promotion PR**: `true`
2. Check if PR is created from `dev` to `staging`

## 🔍 Troubleshooting:

### If Manual Trigger Still Not Showing:
1. **Check repository permissions**: You need write access
2. **Check branch**: Make sure you're on a branch that exists
3. **Wait a moment**: Sometimes GitHub takes a few seconds to update
4. **Refresh the page**: Hard refresh (Ctrl+F5)

### If PR Creation Fails:
1. **Check PRIVATE_REPO_TOKEN**: Must have repo permissions
2. **Check branch existence**: `staging` and `production` branches must exist
3. **Check repository settings**: PRs must be enabled

## 📋 Expected Behavior:

### ✅ **Manual Workflow Should:**
- Show up in Actions tab with "Run workflow" button
- Execute based on selected options
- Create PRs when `create_promotion_pr` is true

### ✅ **PR Creation Should:**
- Create PR from `dev` → `staging` after successful dev deployment
- Create PR from `staging` → `production` after successful staging deployment
- Include detailed description with deployment status
- Add appropriate labels and reviewers

## 🎯 Next Steps:
1. Test manual workflow first
2. If working, test PR creation
3. If both work, you have a fully functional GitOps pipeline!