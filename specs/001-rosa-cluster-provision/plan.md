# Implementation Plan: ROSA Cluster Provisioning via AAP Survey

**Branch**: `001-rosa-cluster-provision` | **Date**: 2026-10-26 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-rosa-cluster-provision/spec.md`

## Summary

Deliver an end-to-end ROSA **HCP** provisioning and deprovisioning path: AAP
organization `rosa` with survey-driven **provision** and **dedicated
deprovision** job templates; Ansible configures the selected AWS account,
writes isolated Argo apps and cluster values into git; central Argo
app-of-apps + ACM (CAPI/CAPA enabled) deploy the cluster; hub secrets live
in `rosa-hcp-secrets`; spoke Argo applies feature-flag Helm charts
(karpenter, amq stream). Jobs are idempotent, never touch unrelated
clusters, poll for Ready within 90 minutes after git commit, require
force/update to reuse a name, and require re-typing the cluster name to
confirm destroy.

## Technical Context

**Language/Version**: Ansible (YAML) 2.15+ compatible with AAP; Helm 3;
Kubernetes/OpenShift manifests (YAML)

**Primary Dependencies**: Ansible Automation Platform (org/templates/surveys);
Red Hat ACM / Multicluster Engine (CAPI + CAPA); Argo CD (app-of-apps);
ROSA HCP via Cluster API; AWS account configuration; Git (commit/push of
apps + values)

**Storage**: Git repository (desired state); Kubernetes Secrets on hub in
namespace `rosa-hcp-secrets` (runtime only, not in git); sourced `env` file
(gitignored)

**Testing**: Ansible idempotency / check-mode where safe; contract validation
of survey schemas and generated git paths; manual/E2E validation against
non-prod hub + disposable AWS account per [quickstart.md](./quickstart.md)

**Target Platform**: Linux AAP execution environment; hub OpenShift with ACM;
AWS accounts for ROSA HCP spokes

**Project Type**: GitOps / infrastructure automation monorepo (Ansible + Helm
+ Argo + cluster values)

**Performance Goals**: Operator survey submit &lt; 5 minutes active time;
provision job Ready poll default **90 minutes**; Ansible roles small and
replayable

**Constraints**: Secrets never in git; HCP only (classic deferred); separate
Argo apps and ACM isolation labels; static AWS account survey list; create
new artifacts only (do not edit existing apps); documentation updated with
implementation

**Scale/Scope**: v1 feature flags = karpenter + amq stream; OCP 4.20–4.22;
default worker node count = 3 (Helm still supports multiple node pools);
one provision + one deprovision template under AAP org `rosa`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Status |
| --- | --- | --- |
| I. Secrets never enter git | Env gitignored; secrets only in hub `rosa-hcp-secrets`; no secret values in surveys/values committed | PASS |
| II. Source environment variables | Playbooks/docs require sourcing env / equivalent injection before runs | PASS |
| III. Canonical layout | `ansible/`, `ansible/iaac/`, `ansible/playbooks/`, `helm/charts/`, `argo/`, `<cluster>/base-values.yaml`, `<cluster>/base-configs/base-values.yaml` | PASS |
| IV. Small AAP roles | Roles split: CAPI enable, AWS account config, secrets ns, git commit app, readiness poll, deprovision | PASS |
| V. Readable + best practices | Explicit vars, orchestration in playbooks | PASS |
| VI. Nested Helm + enable flags | Chart defaults rich; overrides thin; component `enable` | PASS |
| VII. Living documentation | Root architecture README + per-folder READMEs; CAPI steps documented | PASS |
| VIII. AWS account re-provision | Roles use create-or-update / discovery; no hard-coded orphan IDs | PASS |
| IX. Idempotent Ansible | All playbooks re-runnable; force/update and deprovision confirmations guard destructive paths | PASS |

**Post-Phase 1 re-check**: Design artifacts (`research.md`, `data-model.md`,
`contracts/`, `quickstart.md`) align with the same paths and gates — **PASS**.
No unjustified violations; Complexity Tracking left empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-rosa-cluster-provision/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── aap-survey-provision.md
│   ├── aap-survey-deprovision.md
│   ├── git-artifacts.md
│   └── acm-isolation-labels.md
└── tasks.md             # Created by /speckit-tasks (not this command)
```

### Source Code (repository root)

```text
ansible/
├── README.md
├── iaac/                         # AAP org rosa, job templates, surveys
│   ├── README.md
│   └── ...
├── playbooks/
│   ├── README.md
│   ├── provision-rosa-hcp.yml
│   ├── deprovision-rosa-hcp.yml
│   └── enable-capi-acm.yml
└── roles/
    ├── rosa_hcp_secrets_namespace/
    ├── rosa_capi_enable/
    ├── rosa_aws_account_configure/
    ├── rosa_git_commit_argo_app/
    ├── rosa_cluster_readiness_poll/
    ├── rosa_deprovision_cluster/
    └── rosa_git_remove_artifacts/

argo/
├── README.md
├── app-of-apps/                  # Root app (or extension point); do not mutate unrelated apps
└── clusters/                     # Per-cluster Application manifests (new only)
    └── <clustername>/

helm/
└── charts/
    ├── README.md
    ├── karpenter/                # detailed values + enable flags
    └── amq-streams/

<clustername>/
├── base-values.yaml              # ACM / ROSA HCP deploy values
└── base-configs/
    └── base-values.yaml          # Spoke feature-flag overrides (thin)

README.md                         # Root architecture overview
env                               # gitignored; sourced for credentials
```

**Structure Decision**: Follow constitution layout exactly. No application
`src/` tree—this feature is Ansible IaaC + playbooks/roles, Argo apps, Helm
charts, and per-cluster values. AAP definitions live under `ansible/iaac/`;
runtime orchestration under `ansible/playbooks/` and small roles.

## Complexity Tracking

> No constitution violations requiring justification.
