#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: smoke-test.sh INACTIVE_SLOT" >&2
  exit 1
fi

INACTIVE_SLOT="$1"
SERVICE_NAME="django-${INACTIVE_SLOT}-svc"
POD_NAME="smoke-test-$$"

# Cleanup ephemeral pod on exit regardless of success or failure.
# --rm is intentionally omitted from kubectl run below so that the pod stays schedulable
# long enough for kubectl logs to read its output; this trap is the sole cleanup path.
trap 'kubectl delete pod "${POD_NAME}" --ignore-not-found --wait=false >/dev/null 2>&1 || true' EXIT

# Resolve the ClusterIP of the inactive slot's service.
# ClusterIP is only routable from inside the cluster — never exposed externally.
CLUSTER_IP=$(kubectl get svc "${SERVICE_NAME}" -o jsonpath='{.spec.clusterIP}')

if [[ -z "${CLUSTER_IP}" ]]; then
  echo "ERROR: Could not resolve ClusterIP for service ${SERVICE_NAME}. Does the service exist?" >&2
  exit 1
fi

echo "Smoke testing ${SERVICE_NAME} at ClusterIP ${CLUSTER_IP}/healthz/" >&2

# Run the curl pod without -i to avoid kubectl scheduling messages contaminating stdout.
# --rm is omitted so the pod persists until kubectl logs reads its output.
# The EXIT trap above handles deletion.
kubectl run "${POD_NAME}" \
  --image=curlimages/curl:8.7.1 \
  --restart=Never \
  -- curl -s -o /dev/null -w "%{http_code}" \
  "http://${CLUSTER_IP}/healthz/" >/dev/null 2>&1

# Wait up to 60 seconds for the pod to reach a terminal phase (Succeeded or Failed).
DEADLINE=$(( $(date +%s) + 60 ))
PHASE=""
while [[ $(date +%s) -lt $DEADLINE ]]; do
  PHASE=$(kubectl get pod "${POD_NAME}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  [[ "${PHASE}" == "Succeeded" || "${PHASE}" == "Failed" ]] && break
  sleep 2
done

if [[ "${PHASE}" != "Succeeded" && "${PHASE}" != "Failed" ]]; then
  echo "ERROR: Smoke test pod did not complete within 60 seconds (phase: ${PHASE:-Unknown}). Inactive slot: ${INACTIVE_SLOT}" >&2
  exit 1
fi

# kubectl logs returns only the container's stdout — the clean %{http_code} string from curl.
HTTP_CODE=$(kubectl logs "${POD_NAME}")

if [[ "${HTTP_CODE}" == "200" ]]; then
  echo "Smoke test passed: HTTP ${HTTP_CODE}" >&2
  exit 0
else
  echo "ERROR: Smoke test FAILED. HTTP status: ${HTTP_CODE}. Inactive slot: ${INACTIVE_SLOT}" >&2
  exit 1
fi
