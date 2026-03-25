#!/usr/bin/env bash
set -euo pipefail

# Creates the GCS Terraform state bucket for talana-sre-challenge.
# Run ONCE before any terraform init.
#
# Usage: $0 <gcp-project-id> [region]
# After running, import the bucket into Terraform: make bootstrap-import PROJECT_ID=<id>

PROJECT_ID="${1:-}"
REGION="${2:-us-central1}"
BUCKET_NAME="talana-state-bucket"

if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: $0 <gcp-project-id> [region]"
  exit 1
fi

if gsutil ls "gs://${BUCKET_NAME}" > /dev/null 2>&1; then
  echo "Bucket gs://${BUCKET_NAME} already exists — skipping creation."
else
  gsutil mb -p "$PROJECT_ID" -l "$REGION" "gs://${BUCKET_NAME}"
  echo "Bucket gs://${BUCKET_NAME} created."
fi

gsutil versioning set on "gs://${BUCKET_NAME}"
echo "Versioning enabled on gs://${BUCKET_NAME}."
