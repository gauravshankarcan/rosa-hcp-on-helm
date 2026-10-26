# Enable CAPI APIs on ACM (ROSA HCP path)

## Prerequisites

- Hub OpenShift with ACM / Multicluster Engine installed
- `oc` / kube credentials via sourced `env` + `scripts/hub-login.sh`
- Permissions to patch `MultiClusterEngine` and `ClusterManager`

## Automated path

```bash
source ./env
./scripts/hub-login.sh
export KUBECONFIG=$PWD/.kube/hub.kubeconfig
cd ansible
ansible-playbook -i inventory/localhost.yml playbooks/enable-capi-acm.yml
```

## What the automation does

1. Disables MCE components `hypershift` and `hypershift-local-hosting`
2. Enables `cluster-api` and `cluster-api-provider-aws`
3. Enables ClusterManager feature gates `ClusterImporter` and `ManagedClusterAutoApproval`
4. Attempts CAPI registration ClusterRoleBinding (version-dependent)
5. Waits until `capi-controller-manager` and `capa-controller-manager` are Ready in `multicluster-engine`

## Manual verification

```bash
oc get multiclusterengine
oc get deploy -n multicluster-engine | grep -E 'capi|capa'
oc get clustermanager cluster-manager -o yaml | grep -A20 registrationConfiguration
```

## Hypershift exclusivity (important)

Multicluster Engine **forbids** enabling `cluster-api` / `cluster-api-provider-aws`
while `hypershift` / `hypershift-local-hosting` are enabled.

On hubs that already run HostedClusters, this project **defaults to preserving
Hypershift** (`rosa_preserve_hypershift=true`). Provision still writes git/Argo
artifacts and configures AWS secrets; CAPI apply + Ready poll soft-skip until
you use a dedicated CAPI hub (or intentionally disable Hypershift with
`rosa_force_disable_hypershift=true` and `rosa_preserve_hypershift=false` —
destructive to existing HCP workloads).

## Recovery

- Re-run the playbook (idempotent).
- If controllers never become Ready, inspect MCE operator logs and ensure ACM version supports ROSA HCP via CAPI (e.g. ACM 2.15+ guidance).
- If ClusterRoleBinding fails, confirm the ClusterRole name for your ACM build and adjust the role task.

## Rollback notes

Re-enable hypershift components only if you intentionally leave the ROSA HCP CAPI path; do not leave conflicting component sets undocumented.
