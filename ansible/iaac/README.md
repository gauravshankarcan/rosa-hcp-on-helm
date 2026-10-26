# ansible/iaac/

Ansible Automation Platform definitions for organization **`rosa`**.

## Contents

- `organization-rosa.yml` — org scaffold
- `job-template-provision-rosa-hcp.yml` — provision survey (HCP only, static AWS list, force_update)
- `job-template-deprovision-rosa-hcp.yml` — dedicated destroy survey (confirm name)
- `acm-policies/` — Placement/Policy selecting only `rosa-hcp-on-helm/managed=true`

## Adding an AWS account

1. Add the account id to the survey `choices` list in both job templates.
2. Create hub secret `rosa-aws-<account_id>` in `rosa-hcp-secrets` (never commit values).
3. No other git secret material is required.

## Importing into AAP

Use your Controller collection/`awx.awx` export-import flow or recreate surveys in the UI to match the YAML contracts. Point the project at this git repository and playbooks under `ansible/playbooks/`.
