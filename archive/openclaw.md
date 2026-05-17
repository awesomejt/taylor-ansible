# OpenClaw Status

Current status: dormant (retained for future use, not part of active rollout).

## Why Dormant

- Current platform focus is on Traefik-routed Compose services and Hermes profile workflows.
- OpenClaw remains available if future requirements bring it back.

## Active Assets Kept In Place

- Playbook: `openclaw.yaml`
- Role: `roles/openclaw/`
- Inventory group: `openclaw`

## Reactivation Steps

1. Review and update `vars/common/vars.yaml` OpenClaw values (provider/model/channel IDs).
2. Ensure required secrets are set in vaulted `vars/common/secrets.yaml` on `192.168.50.11`.
3. Validate locally:
   - `ansible-playbook --syntax-check -i inventory.ini openclaw.yaml`
   - `ansible-lint openclaw.yaml`
4. Sync to Ansible host:
   - `./sync-to-ansible.sh`
5. Apply from Ansible host:
   - `ssh 192.168.50.11`
   - `cd ~/ansible`
   - `ansible-playbook -i inventory.ini openclaw.yaml --vault-password-file ~/avpass`
6. Verify service and any configured reverse proxy routes.

## Optional Future Hard Archive

If you decide OpenClaw should be fully removed from active tree, move:

- `openclaw.yaml` -> `archive/playbooks/openclaw.yaml`
- `roles/openclaw/` -> `archive/roles/openclaw/`

Then remove references from active docs and inventory as needed.
