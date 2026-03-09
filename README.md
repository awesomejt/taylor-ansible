# taylor-ansible

Ansible playbooks and roles for homelab hosts.

## Playbooks

Run Technitium DNS setup against hosts in the `dns` inventory group:

```bash
ansible-playbook -i inventory.ini dns.yaml
```

Run PostgreSQL 18 setup against hosts in the `postgres` inventory group:

```bash
ansible-galaxy collection install community.postgresql
ansible-playbook -i inventory.ini postgres.yaml -e env=prod --ask-vault-pass
```

The PostgreSQL playbook expects `vault_postgresql_dbpass` in `vars/<env>/secrets.yaml`.
You can override the default app DB/user (`app`/`app`) with extra vars, for example:

```bash
ansible-playbook -i inventory.ini postgres.yaml -e env=prod --ask-vault-pass -e postgresql_db_name=myapp -e postgresql_db_user=myapp
```

## Sync Files to Ansible Control Server

Use the root-level sync helper to push this repository to your Ansible control server without using Git on that server:

```bash
./sync-to-ansible.sh
```

Default target with no arguments: `jason@192.168.50.12:~/ansible`

Examples:

```bash
./sync-to-ansible.sh
./sync-to-ansible.sh jason@192.168.50.12
./sync-to-ansible.sh jason@192.168.50.12 ansible --dry-run
./sync-to-ansible.sh jason@192.168.50.12 ansible --delete
```

You can set defaults once and then run with no arguments:

```bash
export ANSIBLE_SYNC_HOST=192.168.50.12
export ANSIBLE_SYNC_USER=jason
export ANSIBLE_SYNC_DEST=~/ansible
./sync-to-ansible.sh
```

Notes:

- `--dry-run` shows what would be copied.
- `--delete` removes remote files that no longer exist locally (rsync mode).
- In Git Bash on Windows, the script falls back to tar-over-ssh if `rsync` is unavailable.