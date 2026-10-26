# Quickstart Validation: ROSA HCP Provision via AAP

**Feature**: `001-rosa-cluster-provision`  
**Goal**: Prove end-to-end provision, isolation, feature flags, Ready poll,
force-update gate, and deprovision confirmation — without embedding secrets
in git.

## Prerequisites

- AAP reachable; ability to deploy IaaC under `ansible/iaac/` (org `rosa`).
- Hub OpenShift with ACM / MCE; kube credentials via sourced `env` (gitignored).
- Disposable AWS account id listed in the static survey; matching Secret in
  hub namespace `rosa-hcp-secrets` (see [data-model.md](../data-model.md)).
- Central Argo app-of-apps pointed at this repo’s `argo/` tree.
- Contracts: [aap-survey-provision.md](./contracts/aap-survey-provision.md),
  [aap-survey-deprovision.md](./contracts/aap-survey-deprovision.md),
  [git-artifacts.md](./contracts/git-artifacts.md),
  [acm-isolation-labels.md](./contracts/acm-isolation-labels.md).

## Setup

1. Copy/create local `env` (never commit). Include hub API URL/token (or
   kubeconfig path) and any non-secret toggles (e.g. readiness timeout).
2. `source ./env` (or document AAP credential injection equivalent).
3. Apply/ensure AAP org `rosa` + provision & deprovision templates from
   `ansible/iaac/`.
4. Run CAPI enable playbook once (or rely on provision pre-check):
   `ansible/playbooks/enable-capi-acm.yml` — verify controllers Ready.
5. Create hub namespace/secrets for the test AWS account id.

## Validation scenarios

### V1 — Happy path provision

1. Launch provision survey: unique `cluster_name`, `hcp`, `node_count=3`,
   flags e.g. `karpenter` only, OCP `4.20`, test `aws_account_id`,
   `force_update=false`.
2. **Expect**: Job configures AWS; commits only that cluster’s paths; polls
   Ready; succeeds within 90m (or configured deadline).
3. **Expect**: Spoke gets karpenter enabled; amq-streams not installed.
4. **Expect**: Unrelated `argo/` apps and other `<cluster>/` trees unchanged.

### V2 — Name conflict without force

1. Re-run provision with same `cluster_name`, `force_update=false`.
2. **Expect**: Fail fast; no git diff on that cluster’s artifacts.

### V3 — Force update

1. Re-run with `force_update=true` and a flag change (e.g. add `amq-stream`).
2. **Expect**: Only that cluster’s thin overrides reconcile; Ready poll
   succeeds or fails clearly on timeout.

### V4 — Ready timeout behavior (optional / staging)

1. Use a shortened readiness timeout in env.
2. **Expect**: After commit, job fails with explicit timeout message; re-run
   with normal timeout can still succeed (idempotent).

### V5 — Isolation labels

1. Inspect ManagedCluster / policy placement for the new cluster.
2. **Expect**: Labels per contract; existing unlabeled clusters not selected.

### V6 — Deprovision confirmation failure

1. Run deprovision with `confirm_cluster_name` ≠ `cluster_name`.
2. **Expect**: Job fails; cluster still present.

### V7 — Deprovision success

1. Run deprovision with matching confirmation and correct account.
2. **Expect**: Cluster gone; only that cluster’s git/Argo artifacts removed;
   a second unrelated cluster/app still present.

### V8 — Documentation / CAPI rebuild

1. Follow root README + `ansible/` CAPI section only.
2. **Expect**: Contributor can enable/verify CAPI without tribal steps
   (SC-007).

## Secrets check

- `git status` / PR diff MUST NOT contain Secret data, `env`, or credential
  files.
- Account ids in survey IaaC are OK; secret payloads are not.

## Suggested next step

After implementation tasks exist (`/speckit-tasks`), map each V-scenario to
automated or checklist verification in CI/manual gates.
