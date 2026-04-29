#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
K8S_DIR="${ROOT_DIR}/k8s"
REGION="${1:-us-central1}"

if [[ ! -f "${ROOT_DIR}/terraform/terraform.tfvars" ]]; then
  echo "ERROR: terraform/terraform.tfvars not found. Copy terraform.tfvars.example and fill in values." >&2
  exit 1
fi

# Read project_id and project_name from tfvars
PROJECT_ID=$(grep 'project_id' "${ROOT_DIR}/terraform/terraform.tfvars" | head -1 | sed 's/.*= *"\(.*\)"/\1/')
APP_NAME=$(grep 'project_name' "${ROOT_DIR}/terraform/terraform.tfvars" | head -1 | sed 's/.*= *"\(.*\)"/\1/')

echo "Getting kubectl credentials..."
gcloud container clusters get-credentials "${APP_NAME}-gke-cluster" --region "${REGION}"

echo "Applying K8s manifests..."
sed "s/APP_NAME/${APP_NAME}/g; s/PROJECT_ID/${PROJECT_ID}/g" "${K8S_DIR}/serviceaccount.yaml" | kubectl apply -f -
sed "s/APP_NAME/${APP_NAME}/g; s/YOUR_DOMAIN/$(grep 'domain' "${ROOT_DIR}/terraform/terraform.tfvars" | head -1 | sed 's/.*= *"\(.*\)"/\1/')/g" "${K8S_DIR}/managed-certificate.yaml" | kubectl apply -f -
kubectl apply -f "${K8S_DIR}/frontend-config.yaml"
sed "s/PROJECT_ID/${PROJECT_ID}/g; s/APP_NAME/${APP_NAME}/g; s/GIT_SHA/bootstrap/g; s/YOUR_DOMAIN/$(grep 'domain' "${ROOT_DIR}/terraform/terraform.tfvars" | head -1 | sed 's/.*= *"\(.*\)"/\1/')/g" "${K8S_DIR}/deployment-blue.yaml"  | kubectl apply -f -
sed "s/PROJECT_ID/${PROJECT_ID}/g; s/APP_NAME/${APP_NAME}/g; s/GIT_SHA/bootstrap/g; s/YOUR_DOMAIN/$(grep 'domain' "${ROOT_DIR}/terraform/terraform.tfvars" | head -1 | sed 's/.*= *"\(.*\)"/\1/')/g" "${K8S_DIR}/deployment-green.yaml" | kubectl apply -f -
kubectl apply -f "${K8S_DIR}/service-blue.yaml"
kubectl apply -f "${K8S_DIR}/service-green.yaml"
sed "s/APP_NAME/${APP_NAME}/g" "${K8S_DIR}/ingress.yaml" | kubectl apply -f -

echo "Done. Push to main to trigger the first CD run."
