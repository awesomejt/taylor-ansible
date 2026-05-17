# Archive Guide

This folder tracks dormant playbooks/roles that are intentionally retained for future reuse.

## Archiving Modes

- Soft archive (recommended): keep playbook/role in place, mark as dormant in docs, and avoid using it in regular rollout workflows.
- Hard archive: move playbook/role under `archive/` and remove active references from inventory/docs. Use when you want stricter separation.

## Soft Archive Checklist

- Add a short dormant note at the top of the playbook.
- Add a status note in `README.md`.
- Add a component-specific note file in `archive/<component>.md` with reactivation steps.
- Keep secrets as placeholders only in `vars/common/example-secrets.yaml`.

## Hard Archive Checklist (Optional)

- Move playbooks to `archive/playbooks/` and roles to `archive/roles/`.
- Remove active usage references from `README.md`, task docs, and runbooks.
- Keep an explicit restore procedure in `archive/<component>.md`.
- Validate syntax/lint before and after moves.

## Restore Expectations

When reactivating an archived component:

1. Confirm inventory target host/group.
2. Confirm vaulted secrets are present on `192.168.50.11`.
3. Run local validation (`ansible-playbook --syntax-check`, `ansible-lint`).
4. Sync with `./sync-to-ansible.sh`.
5. Run the playbook from `~/ansible` on `192.168.50.11`.
6. Verify runtime health endpoints.
