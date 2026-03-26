.PHONY: plan apply destroy kubeconfig fmt validate bootstrap bootstrap-import rollback

REGION ?= us-central1

plan:
	@test -f terraform/terraform.tfvars || (echo "ERROR: terraform/terraform.tfvars not found. Copy terraform/terraform.tfvars.example and fill in values." && exit 1)
	cd terraform && terraform plan -var-file=terraform.tfvars

apply:
	@echo "ERROR: Apply is only run in the CD pipeline. For local testing use 'make plan'." && exit 1

fmt:
	cd terraform && terraform fmt -recursive
	cd terraform/bootstrap && terraform fmt -recursive

validate:
	cd terraform && terraform validate
	cd terraform/bootstrap && terraform validate

kubeconfig:
	gcloud container clusters get-credentials talana-gke-cluster --region $(REGION)

# Step 1: create the GCS state bucket via gsutil (runs before terraform init).
bootstrap:
	@test -n "$(PROJECT_ID)" || (echo "ERROR: PROJECT_ID is required. Usage: make bootstrap PROJECT_ID=your-gcp-project-id" && exit 1)
	bash scripts/bootstrap-state.sh "$(PROJECT_ID)" "$(REGION)"

# Step 2: import the bucket into terraform/bootstrap state so Terraform tracks it.
# Run once after 'make bootstrap'. Requires terraform init in terraform/bootstrap first.
bootstrap-import:
	@test -n "$(PROJECT_ID)" || (echo "ERROR: PROJECT_ID is required. Usage: make bootstrap-import PROJECT_ID=your-gcp-project-id" && exit 1)
	cd terraform/bootstrap && terraform init
	cd terraform/bootstrap && terraform import \
	  -var="project_id=$(PROJECT_ID)" \
	  google_storage_bucket.state_bucket talana-state-bucket

## rollback: Re-patch Ingress to a previous slot. Usage: make rollback SLOT=blue|green
rollback:
ifndef SLOT
	$(error SLOT is required. Usage: make rollback SLOT=blue or make rollback SLOT=green)
endif
ifeq ($(filter $(SLOT),blue green),)
	$(error Invalid SLOT value "$(SLOT)". Must be blue or green)
endif
	kubectl patch ingress django-ingress --type=merge -p '{"spec":{"defaultBackend":{"service":{"name":"django-$(SLOT)-svc"}}}}'
	kubectl get ingress django-ingress -o jsonpath='{.spec.defaultBackend.service.name}'
