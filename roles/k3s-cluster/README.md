# k3s-cluster role

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

Inventory groups expected:

- `k3s_<env>_servers`
- `k3s_<env>_agents`

Notes:
- This role is intentionally limited to K3s installation and node join behavior.
- It does not install cert-manager, Argo CD, or seed application secrets.
- Cluster bootstrapping beyond base K3s should happen separately.
