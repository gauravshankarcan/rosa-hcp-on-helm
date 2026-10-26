#!/usr/bin/env bash
# Create/update hub Secret rosa-aws-<account> in rosa-hcp-secrets from sourced env.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/env"

: "${AWS_ACCOUNT:?}"
: "${AWS_ACCESS_KEY:?}"
: "${AWS_SECRET_KEY:?}"
: "${KUBECONFIG:?Run scripts/hub-login.sh first}"

NS=rosa-hcp-secrets
NAME="rosa-aws-${AWS_ACCOUNT}"

oc --kubeconfig="$KUBECONFIG" create namespace "$NS" --dry-run=client -o yaml | oc --kubeconfig="$KUBECONFIG" apply -f -

oc --kubeconfig="$KUBECONFIG" -n "$NS" create secret generic "$NAME" \
  --from-literal=aws_access_key_id="$AWS_ACCESS_KEY" \
  --from-literal=aws_secret_access_key="$AWS_SECRET_KEY" \
  --from-literal=region="${AWS_DEFAULT_REGION:-us-east-1}" \
  --dry-run=client -o yaml | oc --kubeconfig="$KUBECONFIG" apply -f -

echo "Ensured secret ${NS}/${NAME} (values not printed)"
