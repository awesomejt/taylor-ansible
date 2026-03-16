# k3s-cluster role (starter)

Usage:

- Provide per-environment non-secret values in `ansible/vars/<env>/vars.yaml`.
- Provide secret values (Vault) in `ansible/vars/<env>/secrets.yaml`.
- Run the playbook from the repo root:

```bash
ansible-playbook -i inventory.ini k3s-cluster.yaml -e env=stage --ask-vault-pass
```

Required variables (examples):

- `vault_k3s_token` (in `vars/<env>/secrets.yaml`)
- `k3s_registration_address` or `k3s_fqdn` / `k3s_server_name` (in `vars/<env>/vars.yaml`)

Inventory groups expected (recommended):

- `k3s_servers`: one or more server hosts; the first host is treated as primary.
- `k3s_workers`: optional worker nodes (or include them in `k3s_servers`/`k3s_agents`).

Notes:
- This is a minimal, idempotent starter. It uses `curl | sh` installer from k3s and checks for existing `/usr/local/bin/k3s` to avoid re-running.
- Extend tasks to add TLS SANs, and advanced cluster options, or to use a packaged installer if desired.
