# Data Model: ROSA Cluster Provisioning via AAP Survey

**Feature**: `001-rosa-cluster-provision` | **Date**: 2026-10-26

## Entities

### ProvisionRequest

| Field | Type | Rules |
| --- | --- | --- |
| `cluster_name` | string | Required; DNS-1035-ish / ROSA-safe name; unique in this flow unless `force_update` |
| `cluster_type` | enum | v1: `hcp` only |
| `node_count` | integer | Default **3**; min ≥ 1 (exact min/max documented in survey help) |
| `feature_flags` | set of string | Subset of `{karpenter, amq-stream}`; may be empty |
| `ocp_version` | enum | `4.20` \| `4.21` \| `4.22` |
| `aws_account_id` | string | Must exist in static survey list |
| `force_update` | boolean | Default `false` |

**Relationships**: Resolves `AwsAccountBinding`; produces `ClusterGitArtifacts`,
`ArgoClusterApp`, `AcmIsolationLabels`; drives spoke `FeatureEnablement`.

**Validation**:

- If artifacts for `cluster_name` exist and `force_update` is false → reject.
- If `aws_account_id` secret missing on hub → reject before AWS mutate.

### DeprovisionRequest

| Field | Type | Rules |
| --- | --- | --- |
| `cluster_name` | string | Required; target of teardown |
| `confirm_cluster_name` | string | Required; MUST equal `cluster_name` exactly |
| `aws_account_id` | string | Required if needed to tear down cloud resources for that cluster |

**Validation**: Mismatch of confirm → fail, no destroy. Unknown name → fail
or documented no-op with explicit message.

### AwsAccountBinding

| Field | Type | Rules |
| --- | --- | --- |
| `account_id` | string | Survey dropdown value |
| `secret_name` | string | Convention: derived from `account_id` (documented) |
| `secret_namespace` | string | Always `rosa-hcp-secrets` on hub |

**Lifecycle**: Account added by updating static survey + creating hub Secret.
Account replacement = new binding; Ansible re-configures without orphan IDs.

### ClusterGitArtifacts

| Path | Purpose |
| --- | --- |
| `<cluster_name>/base-values.yaml` | ACM / ROSA HCP deploy values |
| `<cluster_name>/base-configs/base-values.yaml` | Thin spoke overrides + feature enables |
| `argo/clusters/<cluster_name>/...` | Dedicated Application (and related) manifests |

**Identity**: `cluster_name` is the primary key for this flow’s artifacts.

### ArgoClusterApp

Isolated Argo CD Application for one cluster; discovered by app-of-apps.
Must not share mutable definition with unrelated apps.

### AcmIsolationLabels

| Label | Example value |
| --- | --- |
| `rosa-hcp-on-helm/managed` | `true` |
| `rosa-hcp-on-helm/cluster` | `<cluster_name>` |

Policies for this flow select `rosa-hcp-on-helm/managed=true` (and optionally
cluster name). Existing clusters without labels are out of scope for these
policies.

### FeatureEnablement

Maps survey flags → spoke Helm enable toggles in
`base-configs/base-values.yaml` (e.g. `karpenter.enabled`, `amqStreams.enabled`).
Unselected → disabled/absent.

### HubSecretsNamespace

| Field | Value |
| --- | --- |
| `name` | `rosa-hcp-secrets` |
| `cluster` | Hub / ACM management cluster |

Contains AWS account secrets and any other runtime secrets referenced by
Ansible (never committed).

### AapRosaOrganization

| Field | Value |
| --- | --- |
| `name` | `rosa` |
| `templates` | Provision job template; dedicated deprovision job template |

## State transitions

### Provision

```text
Requested
  → Validated (survey + secrets + name conflict rules)
  → AwsConfigured
  → GitCommitted
  → ReadyPolling
  → Succeeded (Ready within deadline)
  → FailedTimeout (deadline exceeded; artifacts may remain; re-run safe)
  → FailedValidation | FailedMidstep (re-run idempotent)
```

### Force update

Same as provision starting at Validated with `force_update=true`, reconciling
only that `cluster_name`’s artifacts.

### Deprovision

```text
Requested
  → ConfirmMatched
  → ClusterTeardown
  → GitArtifactsRemoved
  → Succeeded
  → FailedConfirm | FailedMidstep (re-run toward removed state)
```

## Uniqueness & concurrency

- One active desired state per `cluster_name` in this flow.
- Concurrent jobs for the same name: last writer / conflict handling should
  fail closed or rely on git locking practices documented in ansible README
  (prefer fail if another job’s commit races—document operational guidance).
