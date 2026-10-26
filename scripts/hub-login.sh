#!/usr/bin/env bash
# Login to hub OCP using sourced env. Never prints passwords.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/env"

: "${OCP_CENTRAL_SERVER:?OCP_CENTRAL_SERVER required}"
: "${OCP_CENTRAL_USERNAME:?OCP_CENTRAL_USERNAME required}"
: "${OCP_CENTRAL_PASSWORD:?OCP_CENTRAL_PASSWORD required}"

export KUBECONFIG="${KUBECONFIG:-${ROOT}/.kube/hub.kubeconfig}"
mkdir -p "$(dirname "$KUBECONFIG")"

# Prefer CRC kubeconfig if targeting api.crc.testing and file exists
if [[ "$OCP_CENTRAL_SERVER" == *"crc.testing"* ]] && [[ -f "${HOME}/.crc/machines/crc/kubeconfig" ]]; then
  cp -f "${HOME}/.crc/machines/crc/kubeconfig" "$KUBECONFIG"
  chmod 600 "$KUBECONFIG"
fi

oc login "$OCP_CENTRAL_SERVER" \
  --username="$OCP_CENTRAL_USERNAME" \
  --password="$OCP_CENTRAL_PASSWORD" \
  --insecure-skip-tls-verify=true \
  --kubeconfig="$KUBECONFIG"

echo "Hub login OK as $(oc --kubeconfig="$KUBECONFIG" whoami)"
echo "export KUBECONFIG=$KUBECONFIG"
