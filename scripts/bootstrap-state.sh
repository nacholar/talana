#!/usr/bin/env bash
set -euo pipefail

# Creates the GCS Terraform state bucket.
# Run ONCE before any terraform init.
#
# Usage: $0 <gcp-project-id> <bucket-name> [region]
# After running, import the bucket into Terraform: make bootstrap-import PROJECT_ID=<id> BUCKET_NAME=<name>

PROJECT_ID="${1:-}"
BUCKET_NAME="${2:-}"
REGION="${3:-us-central1}"

if [[ -z "$PROJECT_ID" || -z "$BUCKET_NAME" ]]; then
  echo "Usage: $0 <gcp-project-id> <bucket-name> [region]"
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
