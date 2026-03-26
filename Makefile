.PHONY: plan apply destroy kubeconfig fmt validate bootstrap bootstrap-import rollback init k8s-bootstrap

REGION ?= us-central1

init:
	cd terraform && terraform init

plan:
	@test -f terraform/terraform.tfvars || (echo "ERROR: terraform/terraform.tfvars not found. Copy terraform/terraform.tfvars.example and fill in values." && exit 1)
	cd terraform && terraform plan -var-file=terraform.tfvars

apply:
	@test -f terraform/terraform.tfvars || (echo "ERROR: terraform/terraform.tfvars not found. Copy terraform/terraform.tfvars.example and fill in values." && exit 1)
	cd terraform && terraform apply -var-file=terraform.tfvars
	@echo "Setting Django secret key in Secret Manager..."
	@python3 -c "import secrets, string; chars = string.ascii_letters + string.digits + '-_=+'; print(''.join(secrets.choice(chars) for _ in range(50)))" | \
	  gcloud secrets versions add talana-django-secret-key --project=talana-491221 --data-file=-
	@echo "Django secret key set."

destroy:
	@test -f terraform/terraform.tfvars || (echo "ERROR: terraform/terraform.tfvars not found. Copy terraform/terraform.tfvars.example and fill in values." && exit 1)
	@echo "WARNING: This will destroy ALL GCP infrastructure including GKE, Cloud SQL, and networking."
	@echo "Press Ctrl+C within 5 seconds to abort..." && sleep 5
	cd terraform && terraform destroy -var-file=terraform.tfvars
	@echo "Purging soft-deleted GCP resources so re-apply works without name conflicts..."
	-gcloud secrets delete talana-db-password --project=talana-491221 --quiet 2>/dev/null || true
	-gcloud secrets delete talana-db-host --project=talana-491221 --quiet 2>/dev/null || true
	-gcloud secrets delete talana-db-name --project=talana-491221 --quiet 2>/dev/null || true
	-gcloud secrets delete talana-db-user --project=talana-491221 --quiet 2>/dev/null || true
	-gcloud secrets delete talana-django-secret-key --project=talana-491221 --quiet 2>/dev/null || true
	-gcloud iam workload-identity-pools providers delete talana-wif-provider \
	  --workload-identity-pool=talana-wif-pool --location=global \
	  --project=talana-491221 --quiet 2>/dev/null || true
	-gcloud iam workload-identity-pools delete talana-wif-pool \
	  --location=global --project=talana-491221 --quiet 2>/dev/null || true
	@echo "Done. Re-apply is safe: run 'make apply'."

fmt:
	cd terraform && terraform fmt -recursive
	cd terraform/bootstrap && terraform fmt -recursive

validate:
	cd terraform && terraform validate
	cd terraform/bootstrap && terraform validate

kubeconfig:
	gcloud container clusters get-credentials talana-gke-cluster --region $(REGION)

# Apply all base K8s manifests in dependency order.
# Run once after 'make apply' on a fresh cluster, before the first CD push.
k8s-bootstrap: kubeconfig
	kubectl apply -f k8s/serviceaccount.yaml
	kubectl apply -f k8s/managed-certificate.yaml
	kubectl apply -f k8s/frontend-config.yaml
	kubectl apply -f k8s/deployment-blue.yaml
	kubectl apply -f k8s/deployment-green.yaml
	kubectl apply -f k8s/service-blue.yaml
	kubectl apply -f k8s/service-green.yaml
	kubectl apply -f k8s/ingress.yaml

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
