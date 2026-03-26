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
	gcloud container clusters get-credentials talana-gke-cluster --region $(REGION)

fmt:
	cd terraform && terraform fmt -recursive

validate:
	cd terraform && terraform validate

bootstrap:
	@test -n "$(PROJECT_ID)" || (echo "ERROR: PROJECT_ID is required. Usage: make bootstrap PROJECT_ID=<id>" && exit 1)
	bash scripts/bootstrap-state.sh "$(PROJECT_ID)" "$(REGION)"

bootstrap-import:
	@test -n "$(PROJECT_ID)" || (echo "ERROR: PROJECT_ID is required. Usage: make bootstrap-import PROJECT_ID=<id>" && exit 1)
	cd terraform/bootstrap && terraform init
	cd terraform/bootstrap && terraform import \
	  -var="project_id=$(PROJECT_ID)" \
	  google_storage_bucket.state_bucket talana-state-bucket

rollback:
ifndef SLOT
	$(error SLOT is required. Usage: make rollback SLOT=blue or make rollback SLOT=green)
endif
ifeq ($(filter $(SLOT),blue green),)
	$(error Invalid SLOT value "$(SLOT)". Must be blue or green)
endif
	kubectl patch ingress django-ingress --type=merge -p '{"spec":{"defaultBackend":{"service":{"name":"django-$(SLOT)-svc"}}}}'
	kubectl get ingress django-ingress -o jsonpath='{.spec.defaultBackend.service.name}'
