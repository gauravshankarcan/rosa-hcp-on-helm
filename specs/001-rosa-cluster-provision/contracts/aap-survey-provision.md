# Contract: AAP Provision Survey (`rosa` org)

**Consumer**: AAP job template — provision ROSA HCP  
**Producer**: Operator (survey UI) → Ansible playbook variables

## Fields

| Survey variable | Type | Required | Default | Allowed values |
| --- | --- | --- | --- | --- |
| `cluster_name` | text | yes | — | Non-empty; ROSA-safe name |
| `cluster_type` | multiple choice | yes | `hcp` | `hcp` only (v1) |
| `node_count` | integer | yes | `3` | ≥ 1 |
| `feature_flags` | multiselect | no | empty | `karpenter`, `amq-stream` |
| `ocp_version` | multiple choice | yes | — | `4.20`, `4.21`, `4.22` |
| `aws_account_id` | multiple choice | yes | — | Static list maintained in AAP IaaC |
| `force_update` | boolean / choice | yes | `false` | `true` \| `false` |

## Precondition checks (playbook MUST enforce)

1. Source env / inject hub credentials.
2. Ensure hub namespace `rosa-hcp-secrets` exists.
3. Resolve secret for `aws_account_id`; fail if missing.
4. If git artifacts for `cluster_name` exist and `force_update` is false → fail
   with conflict error (no writes).
5. Verify CAPI/CAPA readiness (or run enable role); fail clearly if not ready.

## Postcondition (success)

1. AWS account configured for request (idempotent).
2. New/updated artifacts only under that `cluster_name` (see
   [git-artifacts.md](./git-artifacts.md)).
3. Cluster reports Ready within readiness deadline (default 90m) or job fails
   with timeout.

## Non-goals

- Classic ROSA type.
- Editing unrelated Argo applications.
- Writing secret values into git.
