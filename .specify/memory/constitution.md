<!--
Sync Impact Report
- Version change: 1.0.0 → 1.1.0
- Modified principles: none renamed
- Added principles:
  - VII. Extensive, Living Documentation
  - VIII. AWS Account Re-provisioning Resilience
  - IX. Idempotent, Replayable Ansible with Robust Error Handling
- Added/expanded section content:
  - Development & Review Standards (doc update gates, CAPI/ACM procedure check)
- Removed sections: none
- Follow-up TODOs: none
-->

# rosa-hcp-on-helm Constitution

## Core Principles

### I. Secrets Never Enter Git (NON-NEGOTIABLE)

No secret, credential, token, private key, password, or sensitive
configuration MUST ever be committed, pushed, or submitted to git in any
form (including `.env`, survey defaults, values overrides, committed
playbooks, or Helm values that embed secrets).

- Env files that hold secrets MUST be gitignored and MUST NEVER be staged
  or committed.
- Reviews and automation MUST reject changes that introduce secrets into
  the repository history.
- Secrets MUST be supplied at runtime (sourced env, AAP credentials,
  ACM/governance injection, sealed/external secret mechanisms)—never as
  committed plaintext.

**Rationale**: A single leaked secret compromises AWS accounts, clusters,
and the entire delivery chain. Prevention at the repo boundary is mandatory.

### II. Always Source Environment Variables

Any local or automated run that needs environment variables MUST source
the designated env file (or equivalent secret injection) before executing
Ansible, Helm, or scripts. Operators MUST NOT hard-code account or cluster
secrets into playbooks, charts, or Argo manifests.

- Document which variables are required; keep secret values out of git.
- Prefer runtime injection over checked-in placeholder files that could
  later be filled with real secrets.

**Rationale**: Consistent sourcing keeps credentials out of code while
making runs reproducible across AAP jobs and local development.

### III. Canonical Repository Layout

All work MUST land in the agreed tree. Do not invent parallel roots for
the same concern.

| Concern | Required path |
| --- | --- |
| All Ansible work | `ansible/` |
| Ansible Automation Platform IaaC | `ansible/iaac/` |
| Ansible playbooks | `ansible/playbooks/` |
| Helm charts | `helm/charts/` |
| Argo CD apps | `argo/` |
| ROSA cluster deploy values (ACM) | `<clustername>/base-values.yaml` |
| In-cluster config after ROSA is up | `<clustername>/base-configs/base-values.yaml` |

Argo CD MUST use an app-of-apps pattern so the Red Hat central-cluster
Argo CD instance discovers and syncs new apps from git automatically.

**Rationale**: Predictable layout keeps AAP, ACM, and Argo ownership
clear and makes reviews and automation path-based.

### IV. Small, Targeted, Reusable AAP Roles

AAP/Ansible roles MUST stay small and single-purpose. Prefer multiple
reusable roles over large monolithic roles that mix AWS setup, git
commits, and cluster concerns.

- Each role MUST have a clear responsibility and readable tasks.
- Shared logic MUST be extracted into reusable roles rather than copied.
- Playbooks orchestrate roles; roles do not become catch-all scripts.

**Rationale**: Small roles are easier to test, reuse across job templates,
and reason about when a survey-triggered job fails mid-pipeline.

### V. Readable Code and Best Practices

All Ansible, Helm, and Argo artifacts MUST follow established best
practices for the tool in use and MUST remain readable to a new
contributor.

- Prefer clear naming, explicit variables, and minimal cleverness.
- Structure and comments MUST explain intent where non-obvious; they MUST
  NOT substitute for clear code.
- Prefer conventions already established in this repository when extending it.

**Rationale**: This repo is a multi-team delivery path (AAP → git → Argo →
ROSA → ACM → feature Helm). Clarity reduces operational risk.

### VI. Nested Helm Values and Component Enable Flags

Chart default `values.yaml` MUST be detailed and expose the flags needed
to control chart behavior. Override values files MUST stay minimal and
express only the request-specific deltas.

- Every major Helm component or feature MUST expose an `enable` (or
  equivalent) flag so installs can turn capabilities on or off.
- Nest values by component so overrides remain pointed and defaults remain
  the source of truth for knobs and documentation.

**Rationale**: Rich defaults plus thin overrides keep cluster-specific
files reviewable while charts remain the controllable contract for feature
flags once Argo applies them inside the ROSA cluster.

### VII. Extensive, Living Documentation

Documentation is a first-class deliverable, not an afterthought.

- Every individual folder that owns a concern (for example `ansible/`,
  `ansible/iaac/`, `ansible/playbooks/`, `helm/charts/`, `argo/`, and
  cluster paths) MUST have an extensive README that explains purpose,
  inputs/outputs, how to run or apply changes, and failure/recovery notes.
- The root `README.md` MUST be a detailed architecture overview of the
  full delivery flow (AAP → Ansible/AWS → git → central Argo app-of-apps →
  ROSA via ACM → governance/creds → spoke Argo → Helm feature flags).
- After every implementation change, documentation MUST be updated in the
  same change set (or an immediately linked follow-up) so docs match
  reality.
- Enabling CAPI APIs on ACM MUST be fully documented end-to-end: every
  step, prerequisite, verification, and rollback/recovery note an operator
  needs to repeat the procedure safely.

**Rationale**: Account handoffs, mid-job failures, and ACM/CAPI enablement
are high-cost when tribal knowledge is the only source of truth.

### VIII. AWS Account Re-provisioning Resilience

If an AWS account is deleted and a new AWS account is provisioned, Ansible
(and related AAP IaaC under `ansible/iaac/`) MUST be able to re-configure
that account and re-establish required IaaC state without relying on
orphaned resources from the old account.

- Playbooks and roles MUST accept a new account identity/credentials via
  sourced env or AAP credentials and drive configuration to the desired
  state.
- Automation MUST NOT assume prior account-specific resource IDs remain
  valid; discovery or create-or-update patterns MUST be used.
- Re-configuration steps for a replacement account MUST be covered in the
  relevant folder READMEs.

**Rationale**: Account replacement is an operational reality; the pipeline
must re-bootstrap AWS configuration and IaaC from automation, not manual
tribal steps.

### IX. Idempotent, Replayable Ansible with Robust Error Handling

Ansible automation MUST be robust when a run is interrupted, stuck, or
fails mid-way.

- Tasks and roles MUST be idempotent: re-running the same playbook against
  the same intended state MUST be safe and converge without destructive
  side effects beyond the desired configuration.
- Failed or partial runs MUST be replayable from a clean re-invocation
  (or a documented safe resume point) without requiring manual cleanup of
  half-applied state whenever automation can detect and complete work.
- Error handling MUST be explicit: meaningful failure messages, guarded
  destructive operations, and clear reporting of which step failed so
  operators can re-run confidently.
- Long multi-step flows SHOULD be structured so completed steps are
  detectable on replay (create-or-update, existence checks, or equivalent).

**Rationale**: Survey-triggered AAP jobs will fail in the wild; idempotent
replay is the primary recovery path and must be designed in, not bolted on.

## Repository Layout & Delivery Pipeline

This repository implements the following delivery chain. Changes MUST
respect this flow; do not short-circuit ownership between stages.

1. **AAP** — Job template with survey triggers an Ansible playbook.
2. **Ansible** — Configures the AWS account and commits an Argo CD
   Application (or related manifests) into git under `argo/` (and related
   cluster paths as required).
3. **Central Argo CD** — On the Red Hat central cluster, app-of-apps
   automatically picks up the new app and deploys the ROSA cluster using
   `<clustername>/base-values.yaml` via Red Hat ACM.
4. **ACM governance** — Policies push required credentials and instantiate
   Argo CD on the new cluster.
5. **Spoke Argo CD** — Once running, applies Helm charts from
   `helm/charts/` driven by
   `<clustername>/base-configs/base-values.yaml` and feature enable flags.

Artifacts for each stage MUST live in the paths defined under Principle III.

## Development & Review Standards

- PRs MUST be checked for secrets, correct folder placement, and Helm
  enable-flag / values nesting compliance.
- New AAP capability SHOULD be added as a focused reusable role unless an
  existing role already owns that concern.
- Cluster-specific overrides MUST NOT duplicate full chart defaults; only
  deltas and enable toggles needed for that cluster or request.
- Do not commit env files or any file known to contain secrets.
- Implementation PRs MUST update the affected folder README(s) and, when
  the change alters the delivery flow, the root architecture README.
- Ansible changes MUST preserve idempotency and replay safety; reviewers
  MUST reject one-shot or non-reentrant destructive patterns without a
  documented recovery path.
- Work that enables or changes CAPI APIs on ACM MUST include complete
  step-by-step documentation in the owning folder README (or linked doc
  kept in-repo).

## Governance

This constitution supersedes conflicting informal practice in this
repository. Amendments require an update to this file, a semantic version
bump, and a Sync Impact Report (temporary HTML comment) for human review
before commit.

**Versioning**:

- **MAJOR**: Remove or redefine a non-negotiable principle in a
  backward-incompatible way.
- **MINOR**: Add a principle/section or materially expand guidance.
- **PATCH**: Clarifications, wording, and non-semantic refinements.

**Compliance**: Specs, plans, tasks, and PRs MUST align with these
principles. Reviewers MUST flag secrets-in-git, layout violations,
oversized AAP roles, Helm overrides that restate chart defaults instead of
deltas, missing README updates, non-idempotent Ansible, and undocumented
ACM/CAPI enablement steps. Complexity beyond this constitution MUST be
justified in the change description.

**Version**: 1.1.0 | **Ratified**: 2026-10-26 | **Last Amended**: 2026-10-26
