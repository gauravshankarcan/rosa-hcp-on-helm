# rosa-hcp-on-helm

Survey-driven **ROSA HCP** provisioning on Red Hat ACM using Ansible Automation
Platform, GitOps (Argo CD app-of-apps), and feature-flag Helm charts.

## Architecture overview

```text
AAP (org: rosa)
  └─ Job template + survey
       └─ Ansible playbook
            ├─ source env / hub secrets (rosa-hcp-secrets)
            ├─ enable/verify CAPI + CAPA on Multicluster Engine
            ├─ configure selected AWS account (create-or-update)
            ├─ commit isolated Argo app + cluster values to git
            ├─ apply CAPI ROSA HCP manifests on hub (this cluster only)
            └─ poll ManagedCluster Available (default 90m)

Central Argo CD (app-of-apps)
  └─ discovers argo/clusters/<name>/ automatically

ACM governance (placement: rosa-hcp-on-helm/managed=true only)
  └─ push creds + instantiate spoke Argo (does not select unlabeled clusters)

Spoke Argo CD
  └─ applies helm/charts/* using <name>/base-configs/base-values.yaml enables
```

### Paths (constitution)

| Concern | Path |
| --- | --- |
| Ansible | `ansible/` |
| AAP IaaC | `ansible/iaac/` |
| Playbooks | `ansible/playbooks/` |
| Helm charts | `helm/charts/` |
| Argo apps | `argo/` |
| ACM deploy values | `<cluster>/base-values.yaml` |
| Spoke config | `<cluster>/base-configs/base-values.yaml` |

### Safety

- **Secrets never in git** — use `./env` (gitignored) and hub `rosa-hcp-secrets`
- **`GIT_TOKEN` in `./env`** — Ansible pushes cluster artifacts; use
  `scripts/ensure-argocd-repo-secret.sh` so hub Argo CD can read the same repo
- **HCP only** in v1 (classic deferred)
- **force_update** required to reuse a cluster name
- **Deprovision** is a dedicated job; re-type exact cluster name to confirm
- ACM policies select only `rosa-hcp-on-helm/managed=true`

## Quick start (local)

```bash
cp env.example env   # or use existing env
source ./env
chmod +x scripts/*.sh
./scripts/hub-login.sh
export KUBECONFIG=$PWD/.kube/hub.kubeconfig
./scripts/ensure-aws-account-secret.sh

cd ansible
ansible-galaxy collection install -r collections/requirements.yml
ansible-playbook -i inventory/localhost.yml playbooks/enable-capi-acm.yml
ansible-playbook -i inventory/localhost.yml playbooks/provision-rosa-hcp.yml \
  -e cluster_name=demo1 -e cluster_type=hcp -e node_count=3 \
  -e ocp_version=4.20 -e aws_account_id=$AWS_ACCOUNT \
  -e '{"feature_flags":["karpenter"]}' -e force_update=false
```

See `ansible/README.md`, `specs/001-rosa-cluster-provision/quickstart.md`.

## Spec kit

Feature docs live under `specs/001-rosa-cluster-provision/` (spec, plan, tasks).
