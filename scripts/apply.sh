#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -f "${ROOT_DIR}/terraform/terraform.tfvars" ]]; then
  echo "ERROR: terraform/terraform.tfvars not found. Copy terraform.tfvars.example and fill in values." >&2
  exit 1
fi

# Read project_id and project_name from tfvars
GCP_PROJECT_ID=$(grep 'project_id' "${ROOT_DIR}/terraform/terraform.tfvars" | head -1 | sed 's/.*= *"\(.*\)"/\1/')
APP_NAME=$(grep 'project_name' "${ROOT_DIR}/terraform/terraform.tfvars" | head -1 | sed 's/.*= *"\(.*\)"/\1/')

echo "Applying Terraform..."
cd "${ROOT_DIR}/terraform"
terraform apply -var-file=terraform.tfvars

echo "Setting Django secret key in Secret Manager..."
python3 -c "
import secrets, string
chars = string.ascii_letters + string.digits + '-_=+'
print(''.join(secrets.choice(chars) for _ in range(50)))
" | gcloud secrets versions add "${APP_NAME}-django-secret-key" --project="${GCP_PROJECT_ID}" --data-file=-

echo "Done. Next: make k8s-bootstrap"
