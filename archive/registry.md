# Docker Registry Status

Current status: hard-archived (replaced by Harbor on the consolidated Docker host).

## Why Archived

- Harbor is now the primary registry platform for UI/RBAC/scanning capabilities and LDAP integration.
- Legacy Docker Distribution + nginx + joxit UI remains retained for rollback.

## Archived Assets

- Playbook: `archive/playbooks/registry.yaml`
- Role: `archive/roles/registry/`
- Inventory group: `archived_registry`

## Reactivation Steps

1. Confirm the registry target host/group in `inventory.ini`.
2. Ensure any required secrets are set in vaulted `vars/common/secrets.yaml` on `192.168.50.11`.
3. Validate locally:
   - `ANSIBLE_ROLES_PATH=./roles:./archive/roles ansible-playbook --syntax-check -i inventory.ini archive/playbooks/registry.yaml`
   - `ANSIBLE_ROLES_PATH=./roles:./archive/roles ansible-lint archive/playbooks/registry.yaml`
4. Sync to Ansible host:
   - `./sync-to-ansible.sh`
5. Apply from Ansible host:
   - `ssh 192.168.50.11`
   - `cd ~/ansible`
   - `ANSIBLE_ROLES_PATH=./roles:./archive/roles ansible-playbook -i inventory.ini archive/playbooks/registry.yaml --vault-password-file ~/avpass`
6. Verify routed endpoint behavior for both UI and API paths.
