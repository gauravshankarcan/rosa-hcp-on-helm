# ansible/playbooks/

## Order

1. `enable-capi-acm.yml` (or rely on provision preflight)
2. `provision-rosa-hcp.yml`
3. `deprovision-rosa-hcp.yml` (dedicated)

## Extra vars (provision)

See `../group_vars/all/rosa_provision.yml.example` and
`specs/001-rosa-cluster-provision/contracts/aap-survey-provision.md`.

Useful toggles:

- `force_update=true` — reconcile existing name
- `rosa_skip_readiness_poll=true` — git/apply only (local speed)
- `rosa_apply_capi_cluster=false` — skip hub apply (git artifacts only)
- `rosa_readiness_timeout_minutes` — override default 90

## Deprovision

`confirm_cluster_name` must equal `cluster_name` or the job fails with **no destroy**.
