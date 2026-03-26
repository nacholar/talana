#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: switch-traffic.sh INACTIVE_SLOT ACTIVE_SLOT" >&2
  exit 1
fi

INACTIVE_SLOT="$1"
ACTIVE_SLOT="$2"
TARGET_SVC="django-${INACTIVE_SLOT}-svc"

# Log active slot on any unexpected early exit (e.g., kubectl patch failing).
# The explicit error message at end of the polling loop covers the timeout case.
trap 'echo "ERROR: switch-traffic.sh failed unexpectedly. Active slot: ${ACTIVE_SLOT}" >&2' ERR

echo "Switching Ingress traffic from ${ACTIVE_SLOT} to ${INACTIVE_SLOT}" >&2

# Patch spec.defaultBackend.service.name — this Ingress uses defaultBackend, NOT spec.rules.
# Using spec.rules[0].http.paths[0].backend.service.name would silently have no effect.
# --type=merge is explicit and portable; default strategic-merge-patch is not guaranteed
# to behave identically on all Ingress controllers.
kubectl patch ingress django-ingress \
  --type=merge \
  -p "{\"spec\":{\"defaultBackend\":{\"service\":{\"name\":\"${TARGET_SVC}\"}}}}"

echo "Patch applied. Verifying traffic switch within 30 seconds..." >&2

DEADLINE=$(( $(date +%s) + 30 ))
while [[ $(date +%s) -lt $DEADLINE ]]; do
  CURRENT_SVC=$(kubectl get ingress django-ingress -o jsonpath='{.spec.defaultBackend.service.name}')
  if [[ "${CURRENT_SVC}" == "${TARGET_SVC}" ]]; then
    echo "Traffic switch verified: ingress now routes to ${CURRENT_SVC}" >&2
    exit 0
  fi
  sleep 2
done

echo "ERROR: Traffic switch did not take effect within 30 seconds. Active slot: ${ACTIVE_SLOT}" >&2
exit 1
