#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -f "${ROOT_DIR}/terraform/terraform.tfvars" ]]; then
  echo "ERROR: terraform/terraform.tfvars not found. Copy terraform.tfvars.example and fill in values." >&2
  exit 1
fi

echo "Applying Terraform..."
cd "${ROOT_DIR}/terraform"
terraform apply -var-file=terraform.tfvars

echo "Setting Django secret key in Secret Manager..."
python3 -c "
import secrets, string
chars = string.ascii_letters + string.digits + '-_=+'
print(''.join(secrets.choice(chars) for _ in range(50)))
" | gcloud secrets versions add talana-django-secret-key --project=talana-491221 --data-file=-

echo "Done. Next: make k8s-bootstrap"
