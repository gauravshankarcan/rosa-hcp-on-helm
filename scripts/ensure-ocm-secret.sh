#!/usr/bin/env bash
# Create/update rosa-creds-secret for CAPA from OCM_TOKEN in env.
# Usage: source ./env && export KUBECONFIG=... && ./scripts/ensure-ocm-secret.sh
set -euo pipefail
: "${KUBECONFIG:?Set KUBECONFIG (e.g. after scripts/hub-login.sh)}"
: "${OCM_TOKEN:?Set OCM_TOKEN (offline/API token) in env — never commit it}"
NS_LIST=("${ROSA_OCM_SECRET_NAMESPACE:-multicluster-engine}" "${ROSA_CAPI_NAMESPACE:-default}")
NAME="${ROSA_OCM_SECRET_NAME:-rosa-creds-secret}"
URL="${OCM_API_URL:-https://api.openshift.com}"

for NS in "${NS_LIST[@]}"; do
  oc -n "$NS" create secret generic "$NAME" \
    --from-literal=ocmToken="$OCM_TOKEN" \
    --from-literal=ocmApiUrl="$URL" \
    --dry-run=client -o yaml | oc apply -f -
  echo "Ensured ${NS}/${NAME} (token not printed)"
done
