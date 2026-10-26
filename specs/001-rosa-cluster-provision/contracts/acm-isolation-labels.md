# Contract: ACM Isolation Labels

**Purpose**: Ensure governance policies for this flow never select existing
clusters that are not part of `rosa-hcp-on-helm` provisioning.

## Required labels

| Key | Value | Applied to |
| --- | --- | --- |
| `rosa-hcp-on-helm/managed` | `true` | ManagedCluster / cluster claims created by this flow |
| `rosa-hcp-on-helm/cluster` | `<cluster_name>` | Same objects |

Additional labels MAY be added if they remain unique to this flow and are
documented in `ansible/` and `argo/` READMEs.

## Policy placement rule

Policies that push credentials or instantiate spoke Argo for this feature
MUST use a placement/selector equivalent to:

```text
rosa-hcp-on-helm/managed == "true"
```

They MUST NOT use broad selectors that match unlabeled or differently labeled
existing clusters.

## Verification

- Existing cluster without these labels: policy dry-run / placement preview
  shows **not selected**.
- New cluster with labels: **selected**.
- Deprovision: labels/objects for that cluster removed with the cluster;
  other labeled clusters remain.
