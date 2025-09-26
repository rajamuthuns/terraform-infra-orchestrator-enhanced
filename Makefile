# Terraform Infrastructure Orchestrator - Makefile
# Simple commands for managing infrastructure deployments

.PHONY: help init plan apply destroy clean dev staging prod

# Default target
help:
	@echo "Terraform Infrastructure Orchestrator"
	@echo ""
	@echo "Available commands:"
	@echo "  make dev      - Deploy to development environment"
	@echo "  make staging  - Deploy to staging environment"
	@echo "  make prod     - Deploy to production environment"
	@echo ""
	@echo "  make init ENV=<env>     - Initialize Terraform for environment"
	@echo "  make plan ENV=<env>     - Plan changes for environment"
	@echo "  make apply ENV=<env>    - Apply changes for environment"
	@echo "  make destroy ENV=<env>  - Destroy infrastructure for environment"
	@echo ""
	@echo "  make clean    - Clean up temporary files"
	@echo ""
	@echo "Examples:"
	@echo "  make dev                # Deploy to dev"
	@echo "  make plan ENV=staging   # Plan staging changes"
	@echo "  make apply ENV=prod     # Apply production changes"

# Environment-specific targets
dev:
	@$(MAKE) deploy ENV=dev

staging:
	@$(MAKE) deploy ENV=staging

prod:
	@$(MAKE) deploy ENV=production

# Generic deployment target
deploy:
	@if [ -z "$(ENV)" ]; then \
		echo "Error: ENV variable is required"; \
		echo "Usage: make deploy ENV=<dev|staging|production>"; \
		exit 1; \
	fi
	@echo "🚀 Deploying to $(ENV) environment..."
	@$(MAKE) init ENV=$(ENV)
	@$(MAKE) plan ENV=$(ENV)
	@$(MAKE) apply ENV=$(ENV)

# Initialize Terraform
init:
	@if [ -z "$(ENV)" ]; then \
		echo "Error: ENV variable is required"; \
		exit 1; \
	fi
	@echo "🔧 Initializing Terraform with common backend..."
	@if [ ! -f "shared/backend-common.hcl" ]; then \
		echo "Error: Common backend configuration not found: shared/backend-common.hcl"; \
		echo "Please run the backend setup script first: ./scripts/setup-backend-per-account.sh"; \
		exit 1; \
	fi
	terraform init -backend-config=shared/backend-common.hcl

# Plan changes
plan:
	@if [ -z "$(ENV)" ]; then \
		echo "Error: ENV variable is required"; \
		exit 1; \
	fi
	@echo "📋 Planning changes for $(ENV)..."
	@TFVARS_FILE=$$(case "$(ENV)" in \
		"dev") echo "dev-terraform.tfvars" ;; \
		"staging") echo "stg-terraform.tfvars" ;; \
		"production") echo "prod-terraform.tfvars" ;; \
		*) echo "Error: Invalid environment $(ENV)"; exit 1 ;; \
	esac) && \
	if [ ! -f "tfvars/$$TFVARS_FILE" ]; then \
		echo "Error: tfvars file not found: tfvars/$$TFVARS_FILE"; \
		exit 1; \
	fi && \
	terraform workspace select $(ENV) || terraform workspace new $(ENV) && \
	terraform plan -var-file=tfvars/$$TFVARS_FILE -out=tfplan

# Apply changes
apply:
	@if [ -z "$(ENV)" ]; then \
		echo "Error: ENV variable is required"; \
		exit 1; \
	fi
	@echo "✅ Applying changes for $(ENV)..."
	@if [ -f "tfplan" ]; then \
		terraform apply -auto-approve tfplan; \
	else \
		TFVARS_FILE=$$(case "$(ENV)" in \
			"dev") echo "dev-terraform.tfvars" ;; \
			"staging") echo "stg-terraform.tfvars" ;; \
			"production") echo "prod-terraform.tfvars" ;; \
			*) echo "Error: Invalid environment $(ENV)"; exit 1 ;; \
		esac) && \
		terraform workspace select $(ENV) && \
		terraform apply -auto-approve -var-file=tfvars/$$TFVARS_FILE; \
	fi

# Destroy infrastructure
destroy:
	@if [ -z "$(ENV)" ]; then \
		echo "Error: ENV variable is required"; \
		exit 1; \
	fi
	@echo "🗑️  Destroying infrastructure for $(ENV)..."
	@read -p "Are you sure you want to destroy $(ENV) infrastructure? (yes/no): " confirm && \
	if [ "$$confirm" = "yes" ]; then \
		TFVARS_FILE=$$(case "$(ENV)" in \
			"dev") echo "dev-terraform.tfvars" ;; \
			"staging") echo "stg-terraform.tfvars" ;; \
			"production") echo "prod-terraform.tfvars" ;; \
			*) echo "Error: Invalid environment $(ENV)"; exit 1 ;; \
		esac) && \
		terraform workspace select $(ENV) && \
		terraform destroy -auto-approve -var-file=tfvars/$$TFVARS_FILE; \
	else \
		echo "Destroy cancelled."; \
	fi

# Clean up temporary files
clean:
	@echo "🧹 Cleaning up temporary files..."
	rm -f tfplan
	rm -f plan-output.txt
	rm -f outputs.json
	rm -rf .terraform/
	rm -f .terraform.lock.hcl
	@echo "Clean up completed."

# Show current workspace
workspace:
	@echo "Current Terraform workspace:"
	@terraform workspace show 2>/dev/null || echo "No workspace selected"

# Show outputs for environment
outputs:
	@if [ -z "$(ENV)" ]; then \
		echo "Error: ENV variable is required"; \
		echo "Usage: make outputs ENV=<dev|staging|production>"; \
		exit 1; \
	fi
	@echo "📊 Outputs for $(ENV) environment:"
	@terraform workspace select $(ENV) >/dev/null 2>&1 && terraform output || echo "No outputs available"