# OpenClaw Status

Current status: hard-archived (retained for future use, removed from active rollout paths).

## Why Archived

- Current platform focus is on Traefik-routed Compose services and Hermes profile workflows.
- OpenClaw remains available if future requirements bring it back.

## Archived Assets

- Playbook: `archive/playbooks/openclaw.yaml`
- Role: `archive/roles/openclaw/`
- Inventory group: `archived_openclaw`

## Reactivation Steps

1. Review and update `vars/common/vars.yaml` OpenClaw values (provider/model/channel IDs).
2. Ensure required secrets are set in vaulted `vars/common/secrets.yaml` on `192.168.50.11`.
3. Validate locally:
   - `ANSIBLE_ROLES_PATH=./roles:./archive/roles ansible-playbook --syntax-check -i inventory.ini archive/playbooks/openclaw.yaml`
   - `ANSIBLE_ROLES_PATH=./roles:./archive/roles ansible-lint archive/playbooks/openclaw.yaml`
4. Sync to Ansible host:
   - `./sync-to-ansible.sh`
5. Apply from Ansible host:
   - `ssh 192.168.50.11`
   - `cd ~/ansible`
   - `ANSIBLE_ROLES_PATH=./roles:./archive/roles ansible-playbook -i inventory.ini archive/playbooks/openclaw.yaml --vault-password-file ~/avpass`
6. Verify service and any configured reverse proxy routes.
