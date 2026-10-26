# Contract: Git Artifacts Layout (per cluster)

**Producer**: Ansible `rosa_git_commit_argo_app` (provision/force-update)  
**Consumers**: Central Argo CD app-of-apps; ACM (deploy values); spoke Argo
(feature config)

## Required paths for cluster `<cluster_name>`

```text
<cluster_name>/base-values.yaml
<cluster_name>/base-configs/base-values.yaml
argo/clusters/<cluster_name>/application.yaml   # name may vary; must be dedicated
```

Optional supporting files under `argo/clusters/<cluster_name>/` are allowed if
they do not modify sibling cluster directories.

## `base-values.yaml` (deploy)

- Drives ACM / ROSA HCP cluster creation for this name.
- Includes isolation labels per [acm-isolation-labels.md](./acm-isolation-labels.md).
- Contains no secret values.

## `base-configs/base-values.yaml` (spoke)

- Thin overrides only.
- Feature flags map to enable toggles, for example:

```yaml
karpenter:
  enabled: true   # or false
amqStreams:
  enabled: false
```

- Node pool structure may expand beyond survey `node_count` using chart
  defaults; survey sets a simple count/delta only.

## Mutation rules

| Operation | Allowed writes |
| --- | --- |
| Provision (new name) | Create paths above only |
| Force update | Reconcile paths for that `cluster_name` only |
| Deprovision | Delete/retire paths for that `cluster_name` only |
| Any job | MUST NOT modify other `<other>/` trees or unrelated `argo/` apps |

## App-of-apps expectation

Root app (existing or managed under `argo/app-of-apps/`) MUST auto-discover
new applications under `argo/clusters/*` without manual edit of unrelated
Application specs when a new cluster app is added.
