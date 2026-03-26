#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
K8S_DIR="${ROOT_DIR}/k8s"
PROJECT_ID="talana-491221"
REGION="${1:-us-central1}"

echo "Getting kubectl credentials..."
gcloud container clusters get-credentials talana-gke-cluster --region "${REGION}"

echo "Applying K8s manifests..."
kubectl apply -f "${K8S_DIR}/serviceaccount.yaml"
kubectl apply -f "${K8S_DIR}/managed-certificate.yaml"
kubectl apply -f "${K8S_DIR}/frontend-config.yaml"
sed "s/PROJECT_ID/${PROJECT_ID}/g; s/GIT_SHA/bootstrap/g" "${K8S_DIR}/deployment-blue.yaml"  | kubectl apply -f -
sed "s/PROJECT_ID/${PROJECT_ID}/g; s/GIT_SHA/bootstrap/g" "${K8S_DIR}/deployment-green.yaml" | kubectl apply -f -
kubectl apply -f "${K8S_DIR}/service-blue.yaml"
kubectl apply -f "${K8S_DIR}/service-green.yaml"
kubectl apply -f "${K8S_DIR}/ingress.yaml"

echo "Done. Push to main to trigger the first CD run."
