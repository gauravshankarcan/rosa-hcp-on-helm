# Feature Specification: ROSA Cluster Provisioning via AAP Survey

**Feature Branch**: `001-rosa-cluster-provision`

**Created**: 2026-10-26

**Status**: Draft

**Input**: User description: "source the env to get cluster credentials; AAP job template with survey triggers Ansible to configure AWS, commit Argo app; central Argo (app-of-apps) deploys ROSA via ACM; ACM governance instantiates spoke Argo; spoke Argo applies feature-flag Helm charts; enable CAPI API; create AAP org rosa and template with survey fields (name, type hcp/classic, node counts, feature flags karpenter/amq stream, OCP version, AWS account); separate Argo apps and ACM labels so existing clusters are untouched; secrets in namespace rosa-hcp-secrets; ask questions to clarify"

## Clarifications

### Session 2026-10-26

- Q: When should the AAP provisioning job be considered successful—after AWS config and git commit, or only after the ROSA cluster reports ready? → A: Succeed after git commit, then run a bounded wait/poll for cluster Ready and fail if the deadline is exceeded (Option C).
- Q: If a survey uses a cluster name that already exists for this flow, what should the job do? → A: Require an explicit survey force/update flag before reconciling an existing name (Option D).
- Q: Where must the `rosa-hcp-secrets` namespace exist so Ansible can reference credentials at job runtime? → A: Hub/ACM management cluster only (Option A).
- Q: Is destroying or deprovisioning a ROSA cluster in scope for this feature version? → A: Yes — dedicated deprovision job/survey that removes the cluster and this flow’s git artifacts (Option B).
- Q: What confirmation must an operator provide before the dedicated deprovision job will destroy a cluster? → A: Must re-type the exact cluster name to confirm (Option B).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Request a new ROSA cluster from AAP (Priority: P1)

An platform operator opens the AAP organization `rosa`, launches the
provisioning job template, completes the survey (cluster name, HCP type
for v1, node counts, feature flags, OpenShift version, AWS account, and
optional force/update when reusing a name), and starts the job. The job sources environment/cluster credentials, configures the
selected AWS account, and writes a new, isolated Argo application (and
related cluster values) into git without modifying any existing apps or
clusters. Central Argo discovers the app via app-of-apps and deploys the
ROSA cluster through ACM. ACM applies only policies matched by the new
isolation labels, pushes required credentials, and instantiates Argo on
the new cluster. Spoke Argo then installs only the Helm charts selected
via feature flags.

**Why this priority**: This is the end-to-end value of the feature—self-service
cluster provisioning without touching existing estates.

**Independent Test**: An operator can run one survey-driven job for a
non-production test account/name and observe a new cluster path and Argo
app appear, with no changes to pre-existing Argo apps, ACM labels, or
clusters.

**Acceptance Scenarios**:

1. **Given** the `rosa` AAP organization and provisioning template exist,
   **When** an operator submits a valid survey and runs the job,
   **Then** the AWS account is configured for the request and git gains a
   new Argo app plus cluster values for that cluster only.
2. **Given** central Argo uses app-of-apps on this repository,
   **When** the new app is committed,
   **Then** Argo syncs it and ACM begins ROSA deployment for that cluster
   using the cluster deploy values.
3. **Given** ACM governance and spoke Argo are ready on the new cluster,
   **When** feature flags were selected in the survey,
   **Then** only those selected feature charts are applied on the
   provisioned cluster; unselected features are not installed.
4. **Given** existing clusters and Argo apps already in the environment,
   **When** a new provision job completes,
   **Then** no existing Argo apps, ACM policy bindings for other clusters,
   or cluster configs are modified.
5. **Given** AWS is configured and the new git artifacts are committed,
   **When** the job polls for cluster readiness within the configured
   deadline,
   **Then** the job succeeds if the cluster reaches Ready in time, or fails
   clearly if the deadline is exceeded (bring-up may still continue
   asynchronously after job failure).

---

### User Story 2 - Isolate new work from existing ACM/Argo estates (Priority: P1)

Platform operators need new provisioned clusters to use separate Argo
applications and distinct ACM labels so governance policies meant for this
flow never select or mutate existing clusters.

**Why this priority**: Non-interference with production estates is a hard
safety requirement of the request.

**Independent Test**: Inspect git and ACM after a provision run and confirm
new labels/apps are unique and existing labeled clusters remain unchanged.

**Acceptance Scenarios**:

1. **Given** existing Argo applications in the repository or central Argo,
   **When** Ansible writes the new app,
   **Then** it creates a separate app artifact and does not edit existing
   app definitions.
2. **Given** existing ACM-managed clusters,
   **When** isolation labels for the new flow are applied,
   **Then** policies for this feature match only clusters with those
   labels and do not select existing clusters that lack them.

---

### User Story 3 - Store and use secrets safely for automation (Priority: P2)

Operators store required secrets in a dedicated secrets namespace
`rosa-hcp-secrets` on the **hub/ACM management cluster** (created if
missing). Ansible references those secrets at runtime and sources
environment variables for cluster credentials rather than embedding
secrets in git.

**Why this priority**: Required for safe automation, but depends on the
provisioning path existing.

**Independent Test**: Confirm the secrets namespace exists, required secret
references resolve for a dry/run or job, and no secret values appear in
committed git content.

**Acceptance Scenarios**:

1. **Given** secrets are absent from git,
   **When** the job runs,
   **Then** credentials are obtained by sourcing env and/or referencing
   secrets in `rosa-hcp-secrets`.
2. **Given** the secrets namespace does not exist on the hub/ACM management
   cluster,
   **When** setup or the job prepares the environment,
   **Then** namespace `rosa-hcp-secrets` is created there and usable for
   secret references.

---

### User Story 4 - Enable CAPI APIs for ACM-driven provisioning (Priority: P2)

Operators must be able to enable the CAPI APIs required for ACM to
provision ROSA clusters, with every step documented so the procedure is
repeatable (including after environment rebuilds).

**Why this priority**: Prerequisite for ACM-based cluster creation; delivered
as idempotent automation plus full documentation.

**Independent Test**: Run the enable/verify automation (or re-run after
partial failure), confirm CAPI APIs are enabled on ACM, and confirm in-repo
docs cover every step for rebuilds.

**Acceptance Scenarios**:

1. **Given** ACM is available but CAPI APIs are not yet enabled,
   **When** the idempotent enablement automation for this feature runs,
   **Then** CAPI APIs required for this provisioning path are enabled and
   verifiable; a second run reports no harmful changes.
2. **Given** documentation is required by project governance,
   **When** enablement is delivered,
   **Then** every prerequisite, step, verification, and recovery note is
   documented in-repo for environment rebuilds.

---

### User Story 5 - Deprovision a ROSA cluster via dedicated job (Priority: P2)

An operator launches a **dedicated** deprovision job/survey (separate from
create/update), identifies the cluster by name (and related survey fields
as required), and runs teardown. Automation removes the ROSA cluster for
this flow and deletes or retires only this flow’s git/Argo artifacts for
that cluster—without modifying unrelated apps or clusters.

**Why this priority**: Full lifecycle was chosen for v1; still secondary to
successful create path but required for delivery completeness.

**Independent Test**: Provision a disposable test cluster, run deprovision,
confirm cluster and that cluster’s git artifacts are gone while other
clusters remain untouched.

**Acceptance Scenarios**:

1. **Given** a cluster created by this flow exists,
   **When** the operator runs the dedicated deprovision job with matching
   cluster name and exact name re-typed as confirmation,
   **Then** the cluster is removed and this flow’s git/Argo artifacts for
   that name are removed or retired.
2. **Given** other clusters and Argo apps exist,
   **When** deprovision completes for one cluster,
   **Then** no unrelated apps, labels, or cluster configs are modified.
3. **Given** the confirmation name does not exactly match the target
   cluster name,
   **When** the operator submits deprovision,
   **Then** the job fails without destroying any cluster.

---

### User Story 6 - Recover from a failed or interrupted provision job (Priority: P3)

If Ansible fails or stops mid-run after partial AWS configuration or a
partial git write, an operator can re-run the same survey job safely; the
automation converges to the intended state without corrupting existing
clusters.

**Why this priority**: Operational resilience required by constitution;
secondary to first successful path.

**Independent Test**: Interrupt or fail a job deliberately, re-run with the
same survey inputs, and confirm convergence without changes to unrelated
clusters.

**Acceptance Scenarios**:

1. **Given** a previous job failed after partial AWS configuration,
   **When** the operator re-runs the same job with the same survey,
   **Then** automation completes remaining work idempotently and reports
   clear success or a precise failure point.
2. **Given** the AWS account was replaced with a new account selected in
   the survey,
   **When** the job runs,
   **Then** configuration and IaaC target the new account without requiring
   leftover resources from a deleted account.

---

### Edge Cases

- Survey submitted with a cluster name that already exists and force/update
  is not set—job fails with a clear conflict error.
- Survey submitted with an existing cluster name and force/update is set—
  job reconciles that cluster’s artifacts only (still must not touch other
  clusters’ apps or configs).
- Deprovision requested for a cluster name that does not exist in this
  flow—job fails clearly or no-ops with an explicit message (documented).
- Deprovision confirmation name does not exactly match the target name—
  job fails without destroying any cluster.
- Deprovision interrupted mid-way—re-run is idempotent toward removed
  state for that cluster only.
- AWS account selected but credentials missing or invalid in
  `rosa-hcp-secrets` / sourced env.
- Feature flags empty (no add-on charts)—cluster still provisions with
  base path only.
- Node count at minimum/maximum boundaries; multiple node pools needed
  later via values even if survey collects a simple count.
- Job killed during git commit/push—replay must not duplicate destructive
  changes to other apps.
- Requests or legacy inputs asking for `classic` in v1—must be rejected or
  unavailable in the survey until classic is explicitly added later.
- Central Argo or ACM temporarily unavailable after git commit—job has
  committed artifacts then fails the readiness poll if the cluster does not
  become Ready before the deadline.
- Readiness poll deadline exceeded while cluster is still provisioning—
  job fails with a clear timeout message; re-run remains safe (idempotent).
- AWS account chosen in the static survey list but matching secret named by
  account id is missing from `rosa-hcp-secrets`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide an AAP organization named `rosa` and job
  templates for this flow, including a **provision** template (create /
  force-update) and a **dedicated deprovision** template (separate survey /
  job) that tears down a ROSA cluster created by this flow.
- **FR-002**: The job template survey MUST collect: cluster name; cluster
  type fixed to **HCP only for v1** (classic deferred—do not offer classic
  as a selectable successful path until a later release); node counts (with
  a documented default); feature flags as a multi-select including at least
  `karpenter` and `amq stream`; OpenShift version choices `4.20`, `4.21`,
  and `4.22`; an AWS account selection (dropdown); and an explicit
  **force/update** flag (default off) used only when reconciling an
  existing cluster name.
- **FR-003**: On job start, automation MUST source environment variables
  to obtain cluster credentials required for the run (in addition to any
  secret references).
- **FR-004**: Automation MUST configure the selected AWS account for the
  requested cluster and MUST write the corresponding git artifacts (Argo
  app and cluster values) for that cluster only.
- **FR-005**: Git-committed Argo applications for this feature MUST be new,
  separate apps; automation MUST NOT modify existing Argo application
  definitions.
- **FR-006**: ACM isolation labels for this feature MUST be distinct so
  governance policies for this flow do not select or change existing
  clusters that lack those labels.
- **FR-007**: Central Argo MUST consume the new app via the existing
  app-of-apps pattern so the ROSA cluster deploy values
  (`<clustername>/base-values.yaml`) drive ACM deployment of the cluster
  onto the selected AWS account.
- **FR-008**: After the cluster is up, ACM governance MUST push required
  credentials and instantiate Argo on the new cluster; spoke Argo MUST
  apply in-cluster config from
  `<clustername>/base-configs/base-values.yaml` according to selected
  feature flags.
- **FR-009**: Selected feature flags MUST cause only the corresponding
  add-on Helm charts to be installed on the provisioned cluster;
  unselected flags MUST leave those charts not installed. Chart defaults
  MUST support rich nested controls and per-component enable flags; survey
  overrides MUST remain minimal. Node-related Helm values MUST allow
  multiple node pools even if the survey exposes a simple node count.
- **FR-010**: System MUST create namespace `rosa-hcp-secrets` on the
  **hub/ACM management cluster** if it does not exist and MUST reference
  secrets from that namespace when Ansible needs them; secret values MUST
  NOT be committed to git. This namespace is not required on spoke
  clusters for bootstrap of this flow.
- **FR-011**: CAPI API enablement for ACM MUST be delivered as **both**
  idempotent automation that enables and verifies CAPI, **and** complete
  step-by-step in-repo documentation (prerequisites, steps, verification,
  recovery) for rebuilds.
- **FR-012**: Provisioning automation MUST be idempotent and replayable
  after interruption or failure, with clear error reporting of the failed
  step.
- **FR-013**: AWS account dropdown choices MUST be a **static list** in the
  AAP survey; each selection MUST map to credentials/secrets named by
  account id in namespace `rosa-hcp-secrets`. Adding an account requires
  updating the survey list and creating the corresponding secret(s)—account
  identifiers may appear in git; secret values MUST NOT.
- **FR-014**: Documentation MUST include extensive folder READMEs for
  touched areas and a root architecture overview update describing this
  flow; docs MUST be updated with the implementation.
- **FR-015**: v1 MUST support **HCP only**. Classic MUST be deferred to a
  later release; the survey MUST NOT present classic as a successful option
  until that release (offer HCP only, or equivalent clear HCP-only UX).
- **FR-016**: After successful AWS configuration and git commit of the new
  app/values, the provisioning job MUST run a **bounded wait/poll** until
  the ROSA cluster reports Ready (or equivalent success signal). The job
  MUST succeed only if Ready is observed before the deadline; otherwise it
  MUST fail with a clear timeout/error. The readiness deadline MUST be
  documented (default assumed **90 minutes** unless overridden in
  operational config).
- **FR-017**: If the requested cluster name already exists in this
  provisioning flow and the survey **force/update** flag is not set, the
  job MUST fail fast with a clear conflict error and MUST NOT modify that
  cluster’s artifacts. If force/update is set, the job MAY reconcile git
  values and configuration for that named cluster only; it MUST still not
  modify unrelated clusters or existing apps outside that name.
- **FR-018**: System MUST provide a **dedicated deprovision** job/survey
  (not the same as the create template’s primary action) that removes the
  named ROSA cluster for this flow and removes or retires only that
  cluster’s git/Argo artifacts. Deprovision MUST NOT modify unrelated
  clusters or apps. Deprovision automation MUST be idempotent and
  replayable after interruption.
- **FR-019**: The deprovision survey MUST require the operator to
  **re-type the exact cluster name** as confirmation. If the confirmation
  value does not exactly match the target cluster name, the job MUST fail
  and MUST NOT destroy any cluster.

### Key Entities

- **Provision Request**: Survey payload—name, type (HCP in v1), node
  counts, feature flags, OpenShift version, AWS account, force/update flag.
- **AAP Organization `rosa`**: Container for provision and dedicated
  deprovision templates and related job configuration.
- **Deprovision Request**: Survey payload identifying the cluster to remove
  (cluster name plus exact name re-typed as confirmation; additional
  fields as required for safe teardown).
- **AWS Account Selection**: Static survey dropdown entry mapped to
  credentials in `rosa-hcp-secrets` keyed by account id.
- **Argo Application (new)**: Isolated git-defined app for one cluster;
  discovered by central app-of-apps.
- **ACM Isolation Labels**: Labels that scope governance policies to
  clusters created by this flow only.
- **Cluster Deploy Values**: `<clustername>/base-values.yaml` for ACM/ROSA
  deployment.
- **In-Cluster Config Values**:
  `<clustername>/base-configs/base-values.yaml` for post-provision feature
  charts.
- **Feature Flag**: Toggle (e.g., karpenter, amq stream) selecting which
  add-on charts install on the spoke cluster.
- **Secrets Namespace `rosa-hcp-secrets`**: Hub/ACM management-cluster
  namespace for referenced runtime secrets (not in git).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An authorized operator can submit a complete survey and start
  provisioning in under 5 minutes of active operator time (excluding
  cloud cluster bring-up wait).
- **SC-008**: When cluster bring-up completes within the documented
  readiness deadline, the provisioning job ends in success; when Ready is
  not observed before the deadline, the job ends in failure with an
  explicit timeout (validated in at least one success and one timeout
  test scenario).
- **SC-009**: Submitting an existing cluster name without force/update
  fails without changing that cluster; with force/update set, only that
  named cluster’s request/config is reconciled (validated with one reject
  and one forced-update scenario).
- **SC-010**: After a successful dedicated deprovision run, the named
  cluster from this flow is gone and its git/Argo artifacts for this flow
  are removed or retired; at least one other existing cluster/app remains
  unchanged in the same validation.
- **SC-011**: A deprovision submit with a mistyped confirmation name fails
  with no cluster destroyed (validated at least once).
- **SC-002**: After a successful job, 100% of newly created deployment
  requests and cluster configuration paths correspond only to the
  requested cluster name; zero existing unrelated deployment requests or
  cluster configs are modified.
- **SC-003**: Management policies for this flow apply only to clusters
  that carry this feature’s isolation labels; pre-existing clusters
  without those labels remain unaffected (verified by selector review or
  equivalent dry-run).
- **SC-004**: When the operator selects feature-flag subset A, only
  capabilities in A are enabled on the new cluster; unselected
  capabilities remain disabled/absent after the cluster’s configuration
  sync completes.
- **SC-005**: On a deliberately interrupted job, a single re-run with the
  same survey reaches the intended completed state (or a clear blocking
  error) without operator manual cleanup of unrelated clusters, in at
  least 9 of 10 failure-injection trials during validation.
- **SC-006**: No secret values from the job appear in the committed
  change set; required secrets are available from `rosa-hcp-secrets` on
  the hub/ACM management cluster when the job runs.
- **SC-007**: A new contributor can follow in-repo documentation alone to
  explain the full architecture flow and to complete and verify CAPI API
  enablement without undocumented tribal steps.

## Assumptions

- An AAP instance already exists where organization `rosa` and the job
  template can be created (via IaaC under the project’s Ansible IaaC path
  or equivalent controlled setup).
- Red Hat central-cluster Argo CD already uses app-of-apps against this
  (or the designated) git repository.
- ACM is available on the central management plane for ROSA provisioning
  once CAPI prerequisites are met.
- Default node count for the survey will be a small production-safe default
  (assumed **3** worker nodes unless clarified otherwise); Helm values
  still allow multiple node pools beyond the survey field.
- Initial feature-flag chart set is **karpenter** and **amq stream**;
  additional flags may be added later without changing the survey pattern.
- OpenShift versions offered are exactly **4.20**, **4.21**, and **4.22**
  as listed in the request.
- “Do not touch anything existing” applies to Argo apps, ACM labels/policy
  selection for other clusters, and pre-existing cluster value trees—not
  to creating new files/folders for the new cluster.
- Credentials for hub/cluster access are provided by sourcing env plus
  secrets in `rosa-hcp-secrets` on the hub/ACM management cluster,
  consistent with project constitution.
- Replacement of an AWS account (delete old / provision new) is supported
  by selecting the new account in the survey and re-running configuration,
  per constitution.
- CAPI enablement is both automated (idempotent enable/verify) and fully
  documented; provision jobs may still verify CAPI readiness and fail
  clearly if enablement did not succeed.
- AWS accounts on the survey are maintained as a static AAP survey list;
  operators place matching secrets named by account id in
  `rosa-hcp-secrets`.
- ROSA Classic is out of scope for this feature version; only HCP is
  delivered now, with classic to be added in a later change.
- Default cluster readiness poll deadline for the AAP job is **90 minutes**
  unless operational config overrides it; job success requires Ready within
  that bound after git commit.
- Reusing an existing cluster name requires an explicit survey force/update
  flag; without it the job fails closed on name conflict.
- Cluster destroy/deprovision is in scope via a **dedicated** AAP
  job/survey (separate from create); it removes the cluster and this
  flow’s git artifacts for that name only.
- Deprovision requires re-typing the exact cluster name as confirmation
  before destroy proceeds.
- Explicit out of scope for v1 unless later amended: ROSA Classic; bootstrap
  secrets namespaces on spoke clusters for this flow.
