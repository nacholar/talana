#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: deploy-slot.sh INACTIVE_SLOT GIT_SHA GCP_PROJECT_ID REGISTRY_HOST" >&2
  exit 1
fi

INACTIVE_SLOT="$1"
GIT_SHA="$2"
GCP_PROJECT_ID="$3"
REGISTRY_HOST="$4"

# Validate slot argument — must be exactly 'blue' or 'green'.
if [[ "$INACTIVE_SLOT" != "blue" && "$INACTIVE_SLOT" != "green" ]]; then
  echo "ERROR: Invalid INACTIVE_SLOT '$INACTIVE_SLOT': must be 'blue' or 'green'" >&2
  exit 1
fi

# Substitute PROJECT_ID and GIT_SHA placeholders, then apply the inactive deployment manifest.
# Use \b word boundaries so PROJECT_ID is not matched inside the env var name GCP_PROJECT_ID.
# Use | as delimiter to avoid clashes with / characters that may appear in values.
# Only the inactive slot manifest is processed — the active slot is never touched.
sed \
  -e "s|\bPROJECT_ID\b|${GCP_PROJECT_ID}|g" \
  -e "s|\bGIT_SHA\b|${GIT_SHA}|g" \
  "k8s/deployment-${INACTIVE_SLOT}.yaml" | kubectl apply -f -

# Wait for rollout to complete. Exits non-zero after 5 minutes on timeout.
# On failure the active slot remains untouched — Ingress still points to the active service.
kubectl rollout status "deployment/django-${INACTIVE_SLOT}" --timeout=5m
