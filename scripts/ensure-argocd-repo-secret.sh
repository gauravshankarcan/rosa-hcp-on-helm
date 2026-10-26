#!/usr/bin/env bash
# Create/update Argo CD repository Secret on the hub using GIT_TOKEN from ./env.
# Does not print the token.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/env"

: "${GIT_TOKEN:?GIT_TOKEN required}"
: "${KUBECONFIG:?Run scripts/hub-login.sh first}"

REPO_URL="${ROSA_GIT_REPO_URL:-https://github.com/gauravshankarcan/rosa-hcp-on-helm.git}"
NS="${ARGOCD_NAMESPACE:-openshift-gitops}"
NAME="${ARGOCD_REPO_SECRET_NAME:-rosa-hcp-on-helm-repo}"

oc --kubeconfig="$KUBECONFIG" get ns "$NS" >/dev/null

oc --kubeconfig="$KUBECONFIG" -n "$NS" create secret generic "$NAME" \
  --from-literal=type=git \
  --from-literal=url="$REPO_URL" \
  --from-literal=password="$GIT_TOKEN" \
  --from-literal=username=x-access-token \
  --dry-run=client -o yaml \
  | oc --kubeconfig="$KUBECONFIG" apply -f -

oc --kubeconfig="$KUBECONFIG" -n "$NS" label secret "$NAME" \
  argocd.argoproj.io/secret-type=repository --overwrite

echo "Ensured Argo CD repo secret ${NS}/${NAME} for ${REPO_URL} (token not printed)"
