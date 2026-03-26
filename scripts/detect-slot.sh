#!/usr/bin/env bash
set -euo pipefail

if ! ACTIVE_SVC=$(kubectl get ingress django-ingress -o jsonpath='{.spec.defaultBackend.service.name}'); then
  echo "ERROR: kubectl get ingress django-ingress failed. Check cluster connectivity and RBAC permissions." >&2
  exit 1
fi

if [[ -z "$ACTIVE_SVC" ]]; then
  echo "ERROR: Could not determine active service from ingress. Got empty string." >&2
  exit 1
fi

# Strip -svc suffix to get slot name: django-blue-svc -> blue, django-green-svc -> green
ACTIVE_SLOT="${ACTIVE_SVC#django-}"     # remove leading django-
ACTIVE_SLOT="${ACTIVE_SLOT%-svc}"       # remove trailing -svc

if [[ "$ACTIVE_SLOT" != "blue" && "$ACTIVE_SLOT" != "green" ]]; then
  echo "ERROR: Unexpected active slot '$ACTIVE_SLOT' derived from service '$ACTIVE_SVC'" >&2
  exit 1
fi

if [[ "$ACTIVE_SLOT" == "blue" ]]; then
  INACTIVE_SLOT="green"
else
  INACTIVE_SLOT="blue"
fi

echo "Active slot: $ACTIVE_SLOT" >&2
echo "Inactive slot: $INACTIVE_SLOT" >&2

# Emit to GITHUB_OUTPUT for capture by caller
echo "ACTIVE_SLOT=${ACTIVE_SLOT}"
echo "INACTIVE_SLOT=${INACTIVE_SLOT}"
