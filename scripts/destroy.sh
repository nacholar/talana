#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"

if [[ ! -f "${TF_DIR}/terraform.tfvars" ]]; then
  echo "ERROR: terraform/terraform.tfvars not found." >&2
  exit 1
fi

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
for secret in talana-db-password talana-db-host talana-db-name talana-db-user talana-django-secret-key; do
  gcloud secrets delete "${secret}" --project=talana-491221 --quiet 2>/dev/null || true
done

gcloud iam workload-identity-pools providers delete talana-wif-provider \
  --workload-identity-pool=talana-wif-pool --location=global \
  --project=talana-491221 --quiet 2>/dev/null || true

gcloud iam workload-identity-pools delete talana-wif-pool \
  --location=global --project=talana-491221 --quiet 2>/dev/null || true

echo "Done. Re-apply is safe: make apply"
