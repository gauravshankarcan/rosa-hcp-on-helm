# Research: ROSA Cluster Provisioning via AAP Survey

**Feature**: `001-rosa-cluster-provision` | **Date**: 2026-10-26

## 1. ACM CAPI / CAPA enablement for ROSA HCP

**Decision**: Automate idempotent enablement of Multicluster Engine components
`cluster-api` and `cluster-api-provider-aws`, with `hypershift` and
`hypershift-local-hosting` disabled; enable ClusterManager feature gates
`ClusterImporter` and `ManagedClusterAutoApproval` plus required
ClusterRoleBinding for CAPI registration; document every step in
`ansible/` (and linked README) for rebuilds. Verify
`capi-controller-manager` and `capa-controller-manager` Deployments are Ready
in `multicluster-engine`.

**Rationale**: Spec FR-011 requires both automation and docs. Upstream ACM /
stolostron guidance for ROSA HCP via CAPI matches this sequence (ACM ~2.15+,
OCP 4.16+ hub). Idempotent patches/applies allow safe re-runs (constitution IX).

**Alternatives considered**:

- Manual-only runbook — rejected (spec chose automation + docs).
- Leaving hypershift enabled alongside CAPI — rejected; upstream requires
  hypershift components disabled before enabling cluster-api / CAPA for this path.

**References**: stolostron `cluster-api-installer` Create-rosa-hcp docs; CAPA
ROSA topics; RH cloud experts ACM+ROSA notes.

## 2. Delivery boundary after git commit (Ready poll)

**Decision**: After AWS configure + git commit/push, provision playbook polls
hub/ACM (or ManagedCluster / CAPI cluster status) until Ready or **90 minute**
timeout (overridable). Success only on Ready; timeout fails the AAP job with
a clear message (cluster may still converge later; re-run is safe).

**Rationale**: Spec clarification Option C / FR-016. Avoids unbounded AAP jobs
while still giving operators a definitive pass/fail within a documented SLA.

**Alternatives considered**:

- Succeed at git commit only — rejected (operators would not know bring-up status).
- Wait indefinitely — rejected (AAP job hangs).

## 3. AWS account selection and secrets

**Decision**: Static AAP survey dropdown of account identifiers; credentials
stored as Kubernetes Secrets in hub namespace `rosa-hcp-secrets`, named by
account id convention (documented). Playbooks source `env` for hub/kube and
related vars; never commit secret values. Create namespace if missing.

**Rationale**: Spec FR-013 / FR-010 / clarification Q2-A and Q3-A. Matches
constitution I–II.

**Alternatives considered**:

- Dynamic AAP credential inventory — deferred (more flexible, more AAP coupling).
- Secrets on spoke — rejected for bootstrap of this flow.

## 4. Git / Argo isolation

**Decision**: Each cluster gets a **new** Application under `argo/clusters/<name>/`
(or equivalent path) plus `<name>/base-values.yaml` and
`<name>/base-configs/base-values.yaml`. Automation never edits unrelated
Application manifests. App-of-apps discovers new apps by directory/glob.

**Rationale**: FR-005, FR-007; constitution III. Prevents blast radius on
existing estates.

**Alternatives considered**:

- Single shared Application with multi-source — rejected (harder isolation,
  higher risk of touching existing).

## 5. ACM isolation labels

**Decision**: Apply a dedicated label set (e.g. `rosa-hcp-on-helm/managed=true`
plus `rosa-hcp-on-helm/cluster=<name>`) on ManagedCluster / related objects
created by this flow. Governance Policy placement MUST select only these
labels so existing clusters are untouched.

**Rationale**: FR-006 / SC-003.

**Alternatives considered**:

- Reuse generic ACM labels already on estate — rejected (would select existing
  clusters).

## 6. Helm feature flags and values nesting

**Decision**: Charts under `helm/charts/{karpenter,amq-streams}` with detailed
default `values.yaml` and per-component `enable` flags. Survey multi-select
maps to thin overrides in `<cluster>/base-configs/base-values.yaml` only.
Node survey field defaults to **3**; chart supports multiple node pools via
nested defaults.

**Rationale**: FR-009; constitution VI.

**Alternatives considered**:

- Fat per-cluster values copying full chart defaults — rejected (unreviewable,
  drifts from chart contract).

## 7. Name conflict and deprovision safety

**Decision**: Provision requires `force_update=true` to reconcile an existing
name; otherwise fail closed. Deprovision is a **separate** AAP template;
operator must re-type exact cluster name; mismatch aborts with no destroy.

**Rationale**: Clarifications Q2-D, Q4-B, Q5-B; FR-017–019.

**Alternatives considered**:

- Always overwrite existing name — rejected (accidental clobber).
- Destroy via same template action enum — rejected (spec wants dedicated job).

## 8. Ansible role granularity

**Decision**: Small roles orchestrated by playbooks (secrets ns, CAPI enable,
AWS configure, git commit app, readiness poll, deprovision cluster, git remove
artifacts). Shared helpers only where duplication is clear.

**Rationale**: Constitution IV; supports idempotent mid-failure replay (IX).

**Alternatives considered**:

- One monolithic provision role — rejected (hard to test/reuse/recover).

## 9. Testing approach

**Decision**: Contract checks for survey JSON schemas and expected git path
layouts; Ansible syntax/`ansible-lint` where available; E2E quickstart against
non-prod hub + disposable account; failure-injection re-runs for idempotency
(SC-005 target).

**Rationale**: No application unit-test harness in-repo; validation is
operational + contract-oriented.

**Alternatives considered**:

- Full mocked AWS/ACM unit suite in v1 — deferred (high cost; add later if needed).
