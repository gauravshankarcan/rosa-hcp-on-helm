# Contract: AAP Deprovision Survey (`rosa` org)

**Consumer**: Dedicated AAP job template — deprovision ROSA HCP  
**Producer**: Operator → Ansible deprovision playbook

## Fields

| Survey variable | Type | Required | Default | Allowed values |
| --- | --- | --- | --- | --- |
| `cluster_name` | text | yes | — | Existing cluster in this flow |
| `confirm_cluster_name` | text | yes | — | MUST equal `cluster_name` exactly |
| `aws_account_id` | multiple choice | yes* | — | Static list; *required when cloud teardown needs account creds |

## Precondition checks

1. Source env / inject hub credentials.
2. If `confirm_cluster_name` ≠ `cluster_name` → **fail immediately**; no
   destroy, no git deletes.
3. Resolve account secret when required; fail if missing.
4. Identify only this flow’s artifacts for `cluster_name`.

## Postcondition (success)

1. ROSA cluster for this flow removed (or documented already-absent).
2. Git/Argo artifacts for that `cluster_name` only removed or retired.
3. Unrelated apps/clusters unchanged.
4. Re-run converges to the same removed state (idempotent).

## Non-goals

- Soft-delete retention of secrets in `rosa-hcp-secrets` (account secrets stay
  unless operators remove them separately).
- Destroying clusters not created by this flow.
