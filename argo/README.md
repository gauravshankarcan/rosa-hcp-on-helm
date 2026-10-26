# argo/

## App of apps

`app-of-apps/root-application.yaml` discovers applications under `argo/clusters/`
recursively. Replace `REPLACE_WITH_REPO_URL` with your git remote.

## Per-cluster apps

Automation creates **new** directories only:

```text
argo/clusters/<clustername>/application.yaml
```

Never edit sibling cluster apps when provisioning. Isolation labels:

- `rosa-hcp-on-helm/managed=true`
- `rosa-hcp-on-helm/cluster=<clustername>`

## Verification

After provision, confirm only the new app path changed and existing apps are untouched.
