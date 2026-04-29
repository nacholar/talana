.PHONY: init plan apply destroy kubeconfig k8s-bootstrap fmt validate bootstrap bootstrap-import rollback

REGION ?= us-central1

init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan -var-file=terraform.tfvars

apply:
	bash scripts/apply.sh

destroy:
	bash scripts/destroy.sh

k8s-bootstrap:
	bash scripts/k8s-bootstrap.sh $(REGION)

kubeconfig:
	@test -n "$(APP_NAME)" || (echo "ERROR: APP_NAME is required. Usage: make kubeconfig APP_NAME=<project_name>" && exit 1)
	gcloud container clusters get-credentials $(APP_NAME)-gke-cluster --region $(REGION)

fmt:
	cd terraform && terraform fmt -recursive

validate:
	cd terraform && terraform validate

bootstrap:
	@test -n "$(PROJECT_ID)" || (echo "ERROR: PROJECT_ID is required. Usage: make bootstrap PROJECT_ID=<id> BUCKET_NAME=<name>" && exit 1)
	@test -n "$(BUCKET_NAME)" || (echo "ERROR: BUCKET_NAME is required. Usage: make bootstrap PROJECT_ID=<id> BUCKET_NAME=<name>" && exit 1)
	bash scripts/bootstrap-state.sh "$(PROJECT_ID)" "$(BUCKET_NAME)" "$(REGION)"

bootstrap-import:
	@test -n "$(PROJECT_ID)" || (echo "ERROR: PROJECT_ID and BUCKET_NAME are required." && exit 1)
	@test -n "$(BUCKET_NAME)" || (echo "ERROR: PROJECT_ID and BUCKET_NAME are required." && exit 1)
	cd terraform/bootstrap && terraform init
	cd terraform/bootstrap && terraform import \
	  -var="project_id=$(PROJECT_ID)" \
	  -var="bucket_name=$(BUCKET_NAME)" \
	  google_storage_bucket.state_bucket $(BUCKET_NAME)

rollback:
ifndef SLOT
	$(error SLOT is required. Usage: make rollback SLOT=blue or make rollback SLOT=green)
endif
ifeq ($(filter $(SLOT),blue green),)
	$(error Invalid SLOT value "$(SLOT)". Must be blue or green)
endif
	kubectl patch ingress django-ingress --type=merge -p '{"spec":{"defaultBackend":{"service":{"name":"django-$(SLOT)-svc"}}}}'
	kubectl get ingress django-ingress -o jsonpath='{.spec.defaultBackend.service.name}'
