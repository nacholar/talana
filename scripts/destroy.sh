#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"

if [[ ! -f "${TF_DIR}/terraform.tfvars" ]]; then
  echo "ERROR: terraform/terraform.tfvars not found." >&2
  exit 1
fi

# Read project_id and project_name from tfvars
GCP_PROJECT_ID=$(grep 'project_id' "${TF_DIR}/terraform.tfvars" | head -1 | sed 's/.*= *"\(.*\)"/\1/')
APP_NAME=$(grep 'project_name' "${TF_DIR}/terraform.tfvars" | head -1 | sed 's/.*= *"\(.*\)"/\1/')

echo "WARNING: This will destroy ALL GCP infrastructure including GKE, Cloud SQL, and networking."
echo "Press Ctrl+C within 5 seconds to abort..."
sleep 5

echo "Step 1/3: destroying Cloud SQL instance..."
cd "${TF_DIR}"
terraform destroy \
  -target=module.cloudsql.google_sql_user.app_user \
  -target=module.cloudsql.google_sql_database.app_db \
  -target=module.cloudsql.google_sql_database_instance.postgres \
  -var-file=terraform.tfvars -auto-approve

echo "Waiting 90s for GCP to release the private service networking connection..."
sleep 90

echo "Step 2/3: destroying service networking connection..."
terraform destroy \
  -target=module.cloudsql.google_service_networking_connection.private_vpc_connection \
  -var-file=terraform.tfvars -auto-approve

echo "Step 3/3: destroying remaining infrastructure..."
terraform destroy -var-file=terraform.tfvars -auto-approve

echo "Purging soft-deleted GCP resources so re-apply works without name conflicts..."
for secret in "${APP_NAME}-db-password" "${APP_NAME}-db-host" "${APP_NAME}-db-name" "${APP_NAME}-db-user" "${APP_NAME}-django-secret-key"; do
  gcloud secrets delete "${secret}" --project="${GCP_PROJECT_ID}" --quiet 2>/dev/null || true
done

gcloud iam workload-identity-pools providers delete "${APP_NAME}-wif-provider" \
  --workload-identity-pool="${APP_NAME}-wif-pool" --location=global \
  --project="${GCP_PROJECT_ID}" --quiet 2>/dev/null || true

gcloud iam workload-identity-pools delete "${APP_NAME}-wif-pool" \
  --location=global --project="${GCP_PROJECT_ID}" --quiet 2>/dev/null || true

echo "Done. Re-apply is safe: make apply"
