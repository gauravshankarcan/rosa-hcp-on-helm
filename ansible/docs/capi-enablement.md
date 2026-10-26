# Enable CAPI APIs on ACM (ROSA HCP path)

## Prerequisites

- Hub OpenShift with ACM / Multicluster Engine installed
- `oc` / kube credentials via sourced `env` + `scripts/hub-login.sh`
- Permissions to patch `MultiClusterEngine` and `ClusterManager`
- For cloud create: `OCM_TOKEN` in `env` (see `env.example`) and `./scripts/ensure-ocm-secret.sh`
- Non-AWS hubs (CRC): CAPA uses `AWSClusterStaticIdentity` + `rosa-aws-static-creds` (created by `rosa_aws_account_configure`)

## Automated path

```bash
source ./env
./scripts/hub-login.sh
export KUBECONFIG=$PWD/.kube/hub.kubeconfig
cd ansible
ansible-playbook -i inventory/localhost.yml playbooks/enable-capi-acm.yml
```

## What the automation does

1. Optionally disables MCE components `hypershift` and `hypershift-local-hosting` when
   `rosa_force_disable_hypershift=true` and `rosa_preserve_hypershift=false`
2. Enables `cluster-api` and `cluster-api-provider-aws`
3. Enables ClusterManager feature gates `ClusterImporter` and `ManagedClusterAutoApproval`
   and **verifies they persist** after reconcile
4. Attempts CAPI registration ClusterRoleBinding (version-dependent)
5. Waits until `capi-controller-manager` and `capa-controller-manager` are Ready in `multicluster-engine`

## Fail-closed defaults (FR-011 / FR-016)

- Provision **fails** if CAPI cannot be enabled (Hypershift exclusivity) unless
  `rosa_dry_run_git_only=true`.
- CAPI apply **fails** if OCM secret / full ROSAControlPlane inputs are missing unless
  `rosa_apply_capi_soft_skip=true` (git-only dry-run).
- Ready poll **fails** if ManagedCluster is not Available unless
  `rosa_skip_readiness_poll=true` (documented dry-run only).

## CRC / local-hub ManagedCluster import (important)

CRC hub API (`https://api.crc.testing:6443`) is **not resolvable from AWS spokes**.
After ROSA HCP is ready in OCM:

- `ManagedCluster` may appear as **Hub Accepted** with **Available=Unknown** / not Joined.
- Spoke `klusterlet` logs show `lookup api.crc.testing ... no such host`.

This is expected for a lab CRC hub. Cloud Ready is still valid via:

```bash
rosa describe cluster -c <name>
```

For **Joined/Available=True** in ACM, the hub API URL given to spokes must be
publicly reachable (or otherwise DNS-resolvable from the spoke VPC).

The readiness role fails with a CRC-specific message when the hub looks local and
Available never becomes True (see `rosa_hub_is_local_crc`).

## Manual verification

```bash
oc get multiclusterengine
oc get deploy -n multicluster-engine | grep -E 'capi|capa'
oc get clustermanager cluster-manager -o jsonpath='{range .spec.registrationConfiguration.featureGates[*]}{.feature}={.mode}{"\n"}{end}'
oc get awsclusterstaticidentity
oc get managedcluster
```

## Hypershift exclusivity

Multicluster Engine **forbids** enabling `cluster-api` / `cluster-api-provider-aws`
while `hypershift` / `hypershift-local-hosting` are enabled.

Defaults preserve Hypershift (`rosa_preserve_hypershift=true`). Provision **fails closed**
unless you use a dedicated CAPI hub, intentionally disable Hypershift, or set
`rosa_dry_run_git_only=true`.

## Recovery

- Re-run the playbook (idempotent).
- Ensure `OCM_TOKEN` is sourced and secrets exist in `multicluster-engine` + CAPI namespace.
- If controllers never become Ready, inspect MCE operator logs and ACM version guidance for ROSA HCP via CAPI.
