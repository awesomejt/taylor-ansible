# vault-configure role

Configures HashiCorp Vault after initialization and unseal. This role is
intentionally separate from the `vault` install role — installation and
post-init configuration are different lifecycle events.

## What this role does

1. **KV v2 secrets engine** — enabled at `secret/` (idempotent)
2. **AppRole auth method** — enabled at `approle/` (idempotent)
3. **ESO policy** — read-only access to `secret/data/k3s/*`
4. **Admin policy** — broad write access for Ansible automation
5. **ESO AppRole role** — bound to the ESO policy; generates `role_id` + `secret_id`
6. **Admin token** — 1-year orphan token bound to the admin policy

## Bootstrap sequence

Vault setup has three phases. Only phase 1 is fully manual.

### Phase 1 — Manual (once, on Vault host)

```bash
ssh 192.168.50.13
export VAULT_ADDR=http://127.0.0.1:8200

vault operator init
# Prints 5 unseal keys and the root token.
# Store ALL of these offline in a password manager or secure location.
# You cannot recover them if lost.

vault operator unseal   # repeat 3 times with different keys
vault operator unseal
vault operator unseal
```

### Phase 2 — Manual (before first playbook run, on Ansible host)

Create the secrets file on the Ansible host (192.168.50.11) with the root token:

```bash
ssh 192.168.50.11
cp /path/to/ansible/vars/common/example-secrets.yaml vars/common/secrets.yaml
ansible-vault edit vars/common/secrets.yaml --vault-password-file ~/avpass
# Set vault_root_token to the value from vault operator init
```

### Phase 3 — Automated (vault-configure.yaml playbook)

```bash
# Sync files to Ansible host first
./sync-to-ansible.sh

# Then on 192.168.50.11:
ssh 192.168.50.11
cd ~/ansible
ansible-playbook vault-configure.yaml --vault-password-file ~/avpass
```

The playbook prints the generated `vault_eso_role_id`, `vault_eso_secret_id`,
and `vault_admin_token`. Add them to `vars/common/secrets.yaml` using
`ansible-vault edit`.

### Phase 4 — Retire the root token (recommended)

Once `vault_admin_token` is stored in secrets.yaml, revoke the root token
so it cannot be used if leaked:

```bash
ssh 192.168.50.13
export VAULT_ADDR=http://127.0.0.1:8200
vault login   # use root token
vault token revoke <root-token>
```

Keep the root token value in offline storage as a break-glass credential.
You can generate a new root token with the unseal keys if ever needed:
`vault operator generate-root`.

## Unsealing after restart

Vault re-seals on every restart. To unseal:

```bash
ssh 192.168.50.13
export VAULT_ADDR=http://127.0.0.1:8200
vault operator unseal   # enter key shard 1
vault operator unseal   # enter key shard 2
vault operator unseal   # enter key shard 3
```

Or use the UI at `http://192.168.50.13/ui/`.

Running `vault-configure.yaml` while sealed will fail immediately with
a clear error message describing exactly what to do.

## Re-running the playbook

The playbook is safe to re-run:
- KV engine and AppRole enable are idempotent ("already in use" is treated as OK)
- Policies are always upserted (Vault policy write is inherently idempotent)
- ESO AppRole role config is always upserted
- ESO secret_id and admin token are only generated if the corresponding
  variable is empty/unset in secrets.yaml — set them to skip regeneration

## Key variables

| Variable | Default | Description |
|---|---|---|
| `vault_configure_addr` | `http://127.0.0.1:8200` | Vault API address (local listener) |
| `vault_configure_token` | `{{ vault_root_token }}` | Token used by configure tasks |
| `vault_kv_mount` | `secret` | KV v2 mount path |
| `vault_eso_kv_path` | `k3s` | KV path prefix ESO can read |
| `vault_eso_token_ttl` | `1h` | ESO token TTL |
| `vault_admin_token_ttl` | `8760h` | Admin token TTL (1 year) |

Secrets required in `vars/common/secrets.yaml`:
- `vault_root_token` — required for first run
- `vault_admin_token` — set after first run to skip token regeneration
- `vault_eso_role_id` — set after first run (informational, not sensitive)
- `vault_eso_secret_id` — set after first run to skip secret-id regeneration
