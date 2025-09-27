#!/bin/bash

# Terraform Infrastructure Orchestrator - Deployment Script
# Simple script for local deployments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Terraform Infrastructure Orchestrator - Deployment Script"
    echo ""
    echo "Usage: $0 <environment> [action]"
    echo ""
    echo "Environments:"
    echo "  dev         - Development environment"
    echo "  staging     - Staging environment"
    echo "  production  - Production environment"
    echo ""
    echo "Actions:"
    echo "  plan        - Plan changes only (default)"
    echo "  apply       - Plan and apply changes"
    echo "  destroy     - Destroy infrastructure"
    echo ""
    echo "Examples:"
    echo "  $0 dev                    # Plan dev changes"
    echo "  $0 dev apply              # Deploy to dev"
    echo "  $0 staging plan           # Plan staging changes"
    echo "  $0 production destroy     # Destroy production (with confirmation)"
    echo ""
}

# Check if environment is provided
if [ $# -lt 1 ]; then
    show_usage
    exit 1
fi

ENVIRONMENT=$1
ACTION=${2:-plan}

# Validate environment
case $ENVIRONMENT in
    dev)
        TFVARS_FILE="dev-terraform.tfvars"
        ;;
    staging)
        TFVARS_FILE="stg-terraform.tfvars"
        ;;
    production)
        TFVARS_FILE="prod-terraform.tfvars"
        ;;
    *)
        print_error "Invalid environment: $ENVIRONMENT"
        show_usage
        exit 1
        ;;
esac

# Validate action
case $ACTION in
    plan|apply|destroy)
        ;;
    *)
        print_error "Invalid action: $ACTION"
        show_usage
        exit 1
        ;;
esac

print_status "Starting deployment for environment: $ENVIRONMENT"
print_status "Action: $ACTION"
print_status "Tfvars file: $TFVARS_FILE"

# Check if tfvars file exists
if [ ! -f "tfvars/$TFVARS_FILE" ]; then
    print_error "Tfvars file not found: tfvars/$TFVARS_FILE"
    exit 1
fi

# Check if common backend configuration exists
if [ ! -f "shared/backend-common.hcl" ]; then
    print_warning "Common backend configuration not found: shared/backend-common.hcl"
    print_status "You may need to run the backend setup script first:"
    print_status "./scripts/setup-backend-per-account.sh"
    print_status "Continuing with local state..."
    BACKEND_CONFIG=""
else
    BACKEND_CONFIG="-backend-config=shared/backend-common.hcl"
fi

# Initialize Terraform
print_status "Initializing Terraform..."
if ! terraform init $BACKEND_CONFIG; then
    print_error "Terraform initialization failed"
    exit 1
fi

# Select or create workspace
print_status "Setting up workspace: $ENVIRONMENT"
if ! terraform workspace select $ENVIRONMENT 2>/dev/null; then
    print_status "Creating new workspace: $ENVIRONMENT"
    terraform workspace new $ENVIRONMENT
fi

# Execute the requested action
case $ACTION in
    plan)
        print_status "Planning changes for $ENVIRONMENT..."
        terraform plan -var-file=tfvars/$TFVARS_FILE -out=tfplan
        print_success "Plan completed successfully"
        print_status "To apply these changes, run: $0 $ENVIRONMENT apply"
        ;;
    
    apply)
        print_status "Planning changes for $ENVIRONMENT..."
        terraform plan -var-file=tfvars/$TFVARS_FILE -out=tfplan
        
        print_status "Applying changes for $ENVIRONMENT..."
        if [ "$ENVIRONMENT" = "production" ]; then
            print_warning "You are about to apply changes to PRODUCTION!"
            read -p "Are you sure you want to continue? (yes/no): " confirm
            if [ "$confirm" != "yes" ]; then
                print_status "Apply cancelled"
                exit 0
            fi
        fi
        
        terraform apply -auto-approve tfplan
        print_success "Apply completed successfully"
        
        # Show outputs
        print_status "Infrastructure outputs:"
        terraform output
        ;;
    
    destroy)
        print_warning "You are about to DESTROY infrastructure for $ENVIRONMENT!"
        if [ "$ENVIRONMENT" = "production" ]; then
            print_error "PRODUCTION ENVIRONMENT - This will destroy all production resources!"
        fi
        
        read -p "Type 'yes' to confirm destruction: " confirm
        if [ "$confirm" != "yes" ]; then
            print_status "Destroy cancelled"
            exit 0
        fi
        
        print_status "Destroying infrastructure for $ENVIRONMENT..."
        terraform destroy -auto-approve -var-file=tfvars/$TFVARS_FILE
        print_success "Destroy completed successfully"
        ;;
esac

print_success "Deployment script completed for $ENVIRONMENT"