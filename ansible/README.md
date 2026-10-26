# ansible/

Small, reusable roles orchestrated by playbooks. Source `./env` (repo root) or
set `KUBECONFIG` before runs.

## Playbooks

| Playbook | Purpose |
| --- | --- |
| `playbooks/enable-capi-acm.yml` | Idempotent CAPI/CAPA enable + verify |
| `playbooks/provision-rosa-hcp.yml` | Full provision (secrets → CAPI → AWS → git → apply → Ready poll) |
| `playbooks/deprovision-rosa-hcp.yml` | Confirm name → teardown → remove git artifacts |

## Roles

| Role | Responsibility |
| --- | --- |
| `rosa_hcp_secrets_namespace` | Ensure `rosa-hcp-secrets`; require `rosa-aws-<account_id>` |
| `rosa_capi_enable` | MCE components + ClusterManager gates + verify deployments |
| `rosa_aws_account_configure` | STS check + CAPA-related secrets/identity (create-or-update) |
| `rosa_git_commit_argo_app` | Isolated git artifacts; force_update gate |
| `rosa_apply_capi_cluster` | Apply hub CAPI ROSA HCP manifests for one cluster |
| `rosa_cluster_readiness_poll` | Bounded Ready wait (default 90m) |
| `rosa_deprovision_cluster` | Exact name confirm + delete cluster resources |
| `rosa_git_remove_artifacts` | Delete only `<cluster>/` and `argo/clusters/<cluster>/` |

## Secrets

Create hub secrets with `../scripts/ensure-aws-account-secret.sh`. Naming:
`rosa-aws-<aws_account_id>` in namespace `rosa-hcp-secrets`.

### Git write (`GIT_TOKEN`)

Export `GIT_TOKEN` in `./env` (gitignored). When set, provision/deprovision
roles enable `rosa_git_push` and use role `rosa_git_auth_push` to push with
`https://x-access-token:<token>@...` (token never logged). Optional:
`ROSA_GIT_REPO_URL`, `ROSA_GIT_BRANCH`.

For Argo CD on the hub, create a repository credential Secret that uses the
same token (or a deploy key) — do not commit that Secret to git.

## CAPI enablement

See [docs/capi-enablement.md](docs/capi-enablement.md).

## AWS account replacement

1. Add account id to AAP survey static list (`iaac/job-template-provision-rosa-hcp.yml`).
2. Create new hub secret for the new account id.
3. Re-run provision/configure — roles do not assume orphaned resource IDs.

## Failure / replay

Every major step is prefixed `STEP <name>`. Re-run the same playbook after
interruption; roles are idempotent. Use `force_update=true` only when intentionally
reconciling an existing name.
