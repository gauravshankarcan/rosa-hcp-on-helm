# Tasks: ROSA Cluster Provisioning via AAP Survey

**Input**: Design documents from `/specs/001-rosa-cluster-provision/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Not requested in the feature specification — no dedicated test-task phase. Validate via [quickstart.md](./quickstart.md) scenarios in Polish.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Repository layout per plan/constitution: `ansible/`, `ansible/iaac/`, `ansible/playbooks/`, `ansible/roles/`, `argo/`, `helm/charts/`, `<clustername>/`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create canonical directory tree and ignore rules for secrets

- [x] T001 Create directory tree `ansible/iaac/`, `ansible/playbooks/`, `ansible/roles/`, `argo/app-of-apps/`, `argo/clusters/`, `helm/charts/` per plan.md Project Structure
- [x] T002 [P] Verify root `.gitignore` ignores `env` and add patterns for `*.pem`, `*secret*`, `.vault_pass` if missing in `.gitignore`
- [x] T003 [P] Add `env.example` at repo root documenting required variable names only (no secret values) for hub kubeconfig/API and readiness timeout
- [x] T004 [P] Create stub `ansible/ansible.cfg` with roles_path=`ansible/roles` and reasonable defaults for AAP-compatible runs

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared variable schema, role skeletons, and AAP org scaffold that all stories reuse

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Document ProvisionRequest field constraints (`cluster_name` required; `cluster_type` enum `hcp` only; `node_count` integer default 3 min ≥ 1; `feature_flags` subset of `karpenter`,`amq-stream`; `ocp_version` enum `4.20`|`4.21`|`4.22`; `aws_account_id` required; `force_update` boolean default false) in `ansible/group_vars/all/rosa_provision.yml.example`
- [x] T006 [P] Document DeprovisionRequest fields (`cluster_name` required; `confirm_cluster_name` required must equal `cluster_name`; `aws_account_id` when cloud teardown needs creds) in `ansible/group_vars/all/rosa_deprovision.yml.example`
- [x] T007 [P] Create empty role skeletons with `tasks/main.yml`, `defaults/main.yml`, `meta/main.yml` for `ansible/roles/rosa_hcp_secrets_namespace/`, `ansible/roles/rosa_capi_enable/`, `ansible/roles/rosa_aws_account_configure/`, `ansible/roles/rosa_git_commit_argo_app/`, `ansible/roles/rosa_cluster_readiness_poll/`, `ansible/roles/rosa_deprovision_cluster/`, `ansible/roles/rosa_git_remove_artifacts/`
- [x] T008 Create AAP organization scaffold for org name `rosa` under `ansible/iaac/organization-rosa.yml` (or equivalent Controller/AAP definition file used by the project)
- [x] T009 [P] Create Argo app-of-apps root stub that discovers `argo/clusters/*` without editing unrelated apps in `argo/app-of-apps/root-application.yaml`
- [x] T010 Add shared fail-fast messaging helpers/notes for step labels in `ansible/playbooks/README.md` (idempotent replay expectations)

**Checkpoint**: Foundation ready — user story implementation can now begin

---

## Phase 3: User Story 1 - Request a new ROSA cluster from AAP (Priority: P1) 🎯 MVP

**Goal**: Survey-driven provision job configures AWS, commits isolated git artifacts, polls Ready (default 90 minutes)

**Independent Test**: Run provision survey for a disposable name/account; observe only that cluster’s paths under `<clustername>/` and `argo/clusters/<clustername>/`; job succeeds on Ready or fails clearly on timeout (quickstart V1/V4)

### Implementation for User Story 1

- [x] T011 [P] [US1] Implement AWS account configure-or-update (no orphan resource ID assumptions) in `ansible/roles/rosa_aws_account_configure/tasks/main.yml` and `ansible/roles/rosa_aws_account_configure/defaults/main.yml`
- [x] T012 [P] [US1] Implement git artifact generation for `<cluster_name>/base-values.yaml` and `<cluster_name>/base-configs/base-values.yaml` plus `argo/clusters/<cluster_name>/application.yaml` per `specs/001-rosa-cluster-provision/contracts/git-artifacts.md` in `ansible/roles/rosa_git_commit_argo_app/`
- [x] T013 [US1] Enforce name-conflict rule in `ansible/roles/rosa_git_commit_argo_app/tasks/main.yml`: if artifacts exist and `force_update` is false → fail with conflict error and make no writes; if `force_update` true → reconcile that `cluster_name` only
- [x] T014 [US1] Implement bounded Ready poll (default 90 minutes, overridable) with clear timeout failure in `ansible/roles/rosa_cluster_readiness_poll/tasks/main.yml` and `ansible/roles/rosa_cluster_readiness_poll/defaults/main.yml`
- [x] T015 [P] [US1] Create Helm chart scaffold with nested defaults and component `enable` flags for karpenter in `helm/charts/karpenter/` (`Chart.yaml`, `values.yaml`, templates)
- [x] T016 [P] [US1] Create Helm chart scaffold with nested defaults and component `enable` flags for amq-streams in `helm/charts/amq-streams/` (`Chart.yaml`, `values.yaml`, templates)
- [x] T017 [US1] Map survey `feature_flags` and `node_count` (default 3) to thin overrides only in generated `<cluster_name>/base-configs/base-values.yaml` from `ansible/roles/rosa_git_commit_argo_app/` (charts remain source of rich defaults; support multiple node pools in chart values)
- [x] T018 [US1] Write provision playbook orchestrating roles in order (source-env precondition documented; AWS → git commit → Ready poll) in `ansible/playbooks/provision-rosa-hcp.yml`
- [x] T019 [US1] Define AAP provision job template + survey fields per `specs/001-rosa-cluster-provision/contracts/aap-survey-provision.md` (`cluster_type` hcp only; OCP 4.20/4.21/4.22; static `aws_account_id` list; `force_update` default false) in `ansible/iaac/job-template-provision-rosa-hcp.yml`
- [x] T020 [US1] Wire AAP provision template to `ansible/playbooks/provision-rosa-hcp.yml` and project/credentials references (no secret values in git) under `ansible/iaac/`

**Checkpoint**: User Story 1 provision path is independently demoable (MVP)

---

## Phase 4: User Story 2 - Isolate new work from existing ACM/Argo estates (Priority: P1)

**Goal**: Separate Argo apps and ACM labels so policies never select existing unlabeled clusters

**Independent Test**: After a provision run, confirm new labels on the new cluster only; placement preview shows existing clusters not selected (quickstart V5)

### Implementation for User Story 2

- [x] T021 [P] [US2] Embed isolation labels `rosa-hcp-on-helm/managed=true` and `rosa-hcp-on-helm/cluster=<cluster_name>` into generated deploy values in `ansible/roles/rosa_git_commit_argo_app/templates/` (or equivalent) per `specs/001-rosa-cluster-provision/contracts/acm-isolation-labels.md`
- [x] T022 [P] [US2] Add ACM governance Policy/Placement manifests selecting only `rosa-hcp-on-helm/managed=true` for creds + spoke Argo instantiation under `argo/` or `ansible/iaac/acm-policies/` (do not broaden selectors to existing estates)
- [x] T023 [US2] Ensure `rosa_git_commit_argo_app` never modifies sibling paths under `argo/clusters/` other than `<cluster_name>/` (guard tasks + comments in `ansible/roles/rosa_git_commit_argo_app/tasks/main.yml`)
- [x] T024 [US2] Document isolation verification steps in `argo/README.md` and `ansible/README.md`

**Checkpoint**: Isolation contracts enforceable and documented

---

## Phase 5: User Story 3 - Store and use secrets safely (Priority: P2)

**Goal**: Hub namespace `rosa-hcp-secrets`; Ansible references secrets by account id; nothing secret in git

**Independent Test**: Namespace exists on hub; job resolves account secret; `git` diff has no secret payloads (quickstart Secrets check)

### Implementation for User Story 3

- [x] T025 [US3] Implement idempotent create of namespace `rosa-hcp-secrets` on hub in `ansible/roles/rosa_hcp_secrets_namespace/tasks/main.yml`
- [x] T026 [US3] Add secret naming convention by `aws_account_id` and lookup tasks (fail if missing) in `ansible/roles/rosa_hcp_secrets_namespace/` or shared vars under `ansible/group_vars/all/`
- [x] T027 [US3] Invoke secrets namespace role at start of `ansible/playbooks/provision-rosa-hcp.yml` (and document env sourcing prerequisite)
- [x] T028 [P] [US3] Document operator steps to create account Secrets (values never committed) in `ansible/README.md` and hub-facing notes in `ansible/iaac/README.md`

**Checkpoint**: Secrets path usable without git leakage

---

## Phase 6: User Story 4 - Enable CAPI APIs for ACM (Priority: P2)

**Goal**: Idempotent CAPI/CAPA enablement + full step docs for rebuilds

**Independent Test**: Run enable playbook twice; controllers Ready; docs alone suffice for rebuild (quickstart V8)

### Implementation for User Story 4

- [x] T029 [US4] Implement MulticlusterEngine component toggles (disable `hypershift` + `hypershift-local-hosting`; enable `cluster-api` + `cluster-api-provider-aws`) idempotently in `ansible/roles/rosa_capi_enable/tasks/main.yml`
- [x] T030 [US4] Implement ClusterManager feature gates (`ClusterImporter`, `ManagedClusterAutoApproval`) and required ClusterRoleBinding in `ansible/roles/rosa_capi_enable/tasks/`
- [x] T031 [US4] Add verification of `capi-controller-manager` and `capa-controller-manager` Ready in `multicluster-engine` in `ansible/roles/rosa_capi_enable/tasks/verify.yml` (or `tasks/main.yml`)
- [x] T032 [US4] Write `ansible/playbooks/enable-capi-acm.yml` and call verify from `ansible/playbooks/provision-rosa-hcp.yml` preflight (fail clearly if not ready)
- [x] T033 [P] [US4] Write end-to-end CAPI enablement docs (prerequisites, steps, verification, recovery) in `ansible/README.md` section and/or `ansible/docs/capi-enablement.md`

**Checkpoint**: CAPI enable/verify automated and documented

---

## Phase 7: User Story 5 - Deprovision via dedicated job (Priority: P2)

**Goal**: Dedicated deprovision survey/job; re-type name confirmation; remove cluster + this flow’s git artifacts only

**Independent Test**: Mistyped confirm fails with cluster intact (V6); matching confirm removes only that cluster’s artifacts (V7)

### Implementation for User Story 5

- [x] T034 [US5] Implement exact name confirmation gate (`confirm_cluster_name` must equal `cluster_name`) failing with no destroy in `ansible/roles/rosa_deprovision_cluster/tasks/main.yml`
- [x] T035 [US5] Implement idempotent ROSA/ACM cluster teardown for this flow only in `ansible/roles/rosa_deprovision_cluster/tasks/main.yml` and `defaults/main.yml`
- [x] T036 [P] [US5] Implement removal/retirement of only `<cluster_name>/` and `argo/clusters/<cluster_name>/` in `ansible/roles/rosa_git_remove_artifacts/tasks/main.yml`
- [x] T037 [US5] Write `ansible/playbooks/deprovision-rosa-hcp.yml` orchestrating confirm → teardown → git remove (idempotent re-run)
- [x] T038 [US5] Define dedicated AAP deprovision job template + survey per `specs/001-rosa-cluster-provision/contracts/aap-survey-deprovision.md` in `ansible/iaac/job-template-deprovision-rosa-hcp.yml`
- [x] T039 [US5] Document deprovision recovery and unknown-name behavior in `ansible/playbooks/README.md`

**Checkpoint**: Dedicated deprovision path safe and isolated

---

## Phase 8: User Story 6 - Recover from failed or interrupted jobs (Priority: P3)

**Goal**: Idempotent replay after partial failure; clear step errors; AWS account replacement via new survey selection

**Independent Test**: Interrupt mid-run; re-run same survey converges without touching unrelated clusters (quickstart V4 + SC-005 intent)

### Implementation for User Story 6

- [x] T040 [US6] Add per-step failure messages and changed/ok reporting across provision roles in `ansible/roles/rosa_aws_account_configure/`, `ansible/roles/rosa_git_commit_argo_app/`, `ansible/roles/rosa_cluster_readiness_poll/`
- [x] T041 [US6] Add create-or-update / existence checks so re-runs skip completed work safely in `ansible/roles/rosa_aws_account_configure/tasks/main.yml` and `ansible/roles/rosa_git_commit_argo_app/tasks/main.yml`
- [x] T042 [US6] Document AWS account replacement procedure (new dropdown entry + new hub secret; re-run configure) in `ansible/README.md`
- [x] T043 [US6] Mirror idempotent teardown checks for deprovision re-runs in `ansible/roles/rosa_deprovision_cluster/` and `ansible/roles/rosa_git_remove_artifacts/`

**Checkpoint**: Replay-safe provision and deprovision

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Living documentation and validation alignment with constitution VII

- [x] T044 [P] Write extensive `ansible/README.md` covering playbooks, roles, env sourcing, secrets, CAPI, provision/deprovision
- [x] T045 [P] Write extensive `ansible/iaac/README.md` for org `rosa`, survey maintenance (static AWS list), template wiring
- [x] T046 [P] Write extensive `ansible/playbooks/README.md` for run order, timeouts, force_update, confirm name
- [x] T047 [P] Write extensive `argo/README.md` for app-of-apps and per-cluster app isolation
- [x] T048 [P] Write extensive `helm/charts/README.md` for enable flags and override philosophy
- [x] T049 Replace root `README.md` with detailed architecture overview of AAP → Ansible/AWS → git → central Argo → ROSA/ACM → spoke Argo → Helm feature flags
- [x] T050 Cross-check implementation against `specs/001-rosa-cluster-provision/quickstart.md` scenarios V1–V8 and update quickstart paths if filenames drifted
- [x] T051 [P] Ensure no sample/secret values remain in committed YAML under `ansible/`, `argo/`, `helm/` (scan before merge)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — **BLOCKS** all user stories
- **US1 (Phase 3)**: After Foundational — MVP
- **US2 (Phase 4)**: After Foundational; ideally after T012 templates exist (integrates with US1 git role)
- **US3 (Phase 5)**: After Foundational; should complete before relying on E2E provision secrets in shared envs
- **US4 (Phase 6)**: After Foundational; required for Ready success in full E2E
- **US5 (Phase 7)**: After Foundational; practical E2E after US1 artifacts exist
- **US6 (Phase 8)**: After US1 and US5 role bodies exist
- **Polish (Phase 9)**: After desired stories complete

### User Story Dependencies

- **US1 (P1)**: No hard dependency on other stories for git-commit MVP; full Ready E2E needs US3 + US4
- **US2 (P1)**: Extends US1 generated values/policies; independently testable via label/selector review
- **US3 (P2)**: Independently testable (namespace + secret lookup)
- **US4 (P2)**: Independently testable (enable + verify controllers)
- **US5 (P2)**: Independently testable with a disposable cluster from US1
- **US6 (P3)**: Hardens US1/US5; validate with interrupt/re-run

### Parallel Opportunities

- T002–T004 in Setup
- T005–T006, T007 role skeletons, T009 in Foundational
- T011–T012, T015–T016 within US1
- T021–T022 within US2
- T036 parallel with T034–T035 once interfaces agreed
- T044–T048, T051 in Polish

---

## Parallel Example: User Story 1

```bash
# Parallel chart scaffolds + AWS/git roles (different paths):
Task: "T011 AWS configure role in ansible/roles/rosa_aws_account_configure/"
Task: "T012 Git commit role in ansible/roles/rosa_git_commit_argo_app/"
Task: "T015 Helm chart helm/charts/karpenter/"
Task: "T016 Helm chart helm/charts/amq-streams/"

# Then sequential orchestration:
Task: "T018 provision-rosa-hcp.yml"
Task: "T019–T020 AAP iaac job template"
```

---

## Parallel Example: Polish docs

```bash
Task: "T044 ansible/README.md"
Task: "T045 ansible/iaac/README.md"
Task: "T047 argo/README.md"
Task: "T048 helm/charts/README.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: US1 (optionally minimal US3/US4 for E2E Ready)
4. **STOP and VALIDATE** using quickstart V1
5. Demo provision path

### Incremental Delivery

1. Setup + Foundational
2. US1 → validate MVP
3. US2 isolation → validate V5
4. US3 secrets + US4 CAPI → harden E2E
5. US5 deprovision → validate V6/V7
6. US6 idempotency → interrupt/re-run
7. Polish READMEs + quickstart pass

### Parallel Team Strategy

1. Team completes Setup + Foundational together
2. Dev A: US1 (+ charts)
3. Dev B: US2 policies/labels + US4 CAPI
4. Dev C: US3 secrets + US5 deprovision
5. All: US6 hardening + Polish

---

## Notes

- [P] tasks = different files, no incomplete dependencies
- [USn] maps to spec user stories 1–6
- Quote field constraints from data-model/contracts into AAP survey tasks (T019, T038)
- Never commit `env` or secret payloads
- Classic ROSA is out of scope — do not add classic survey options
- Suggested next command: `/speckit-implement`

---

## Phase 10: Convergence

**Purpose**: Close gaps between spec/plan/constitution and current implementation (converge F1–F11)

- [x] T052 CRITICAL Create idempotent `AWSClusterStaticIdentity` plus CAPA credential Secret (`AccessKeyID`/`SecretAccessKey`) in `ansible/roles/rosa_aws_account_configure/` and wire `identityRef` in `rosa_apply_capi_cluster` for non-AWS hubs per FR-004 / plan: AWS account config (missing)
- [x] T053 CRITICAL Fail provision when cluster Ready is not observed: default `rosa_apply_capi_soft_skip` off for real runs and stop readiness soft-success paths in `rosa_cluster_readiness_poll` / `rosa_apply_capi_cluster` per FR-016 / US1/AC5 / SC-008 (contradicts)
- [x] T054 Add in-repo OCM secret ensure from sourced `OCM_TOKEN` (replace `/tmp`-only path) and hard-fail CAPI apply when cloud create requires it in `rosa_apply_capi_cluster` per FR-004 / FR-016 (partial)
- [x] T055 Populate full `ROSAControlPlane` inputs (`rosa_ocp_version` semver, `billingAccount`, complete `rolesRef`, OIDC, subnets) from account/config vars and fail if required fields missing in `rosa_apply_capi_cluster` per FR-004 (partial)
- [x] T056 Re-apply and verify `ClusterImporter` + `ManagedClusterAutoApproval` persist on ClusterManager after reconcile; fail if gates drop in `rosa_capi_enable` per FR-011 / T030 (partial)
- [x] T057 Extend ACM Policy/Placement in `ansible/iaac/acm-policies/` to push required credentials and instantiate spoke Argo CD for isolation-labeled clusters only per FR-008 / US1/AC3 (partial)
- [x] T058 Generate spoke Argo Applications (or ACM-delivered apps) that apply `helm/charts/{karpenter,amq-streams}` from `feature_flags` with thin overrides per FR-009 / US1/AC3 / SC-004 / Constitution VI (missing)
- [x] T059 Make `<cluster>/base-values.yaml` (or derived manifests) the ACM/CAPI deploy source consumed via app-of-apps rather than only a side-channel apply role per FR-007 / plan: base-values → ACM deploy (partial)
- [x] T060 Fail closed when CAPI/CAPA cannot be enabled or verified (override only with explicit documented dry-run that still fails Ready) in `rosa_capi_enable` / provision playbook per FR-011 / US4/AC1 (contradicts)
- [x] T061 Document CRC/local-hub ManagedCluster import reachability limits and fail fast with a clear message when hub cannot complete import in `ansible/docs/capi-enablement.md` and playbooks README per FR-016 (partial)
- [x] T062 Idempotently tear down full CAPI/ROSA object set (`ROSAControlPlane`, `ROSACluster`, machine pools, related secrets) for the named cluster in `rosa_deprovision_cluster` before git artifact removal per FR-018 / US5/AC1 (partial)

---

## Phase 11: Convergence

**Purpose**: Close remaining gaps after Phase 10 (converge F1–F3)

- [x] T063 CRITICAL Bridge Helm thin overrides to chart root `enabled` for karpenter/amq-streams (inline Helm values, per-chart value files, or chart templates) so `feature_flags` actually install/absent per FR-009 / US1/AC3 / SC-004 / Constitution VI (partial)
- [x] T064 Wire survey `node_count` into ROSAControlPlane default machine pool size/replicas in `rosa_apply_capi_cluster` templates so cloud workers match the survey per FR-002 / FR-004 (partial)
- [x] T065 Regenerate or reconcile existing cluster Argo Applications to sync `<cluster>/capi/` (and write CAPI manifests under that path) so app-of-apps consumes CAPI deploy source per FR-007 / plan: base-values → ACM deploy (partial)
