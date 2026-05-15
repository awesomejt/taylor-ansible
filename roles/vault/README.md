# HashiCorp Vault Role

Deploys HashiCorp Vault as a systemd-managed native binary with an Nginx reverse proxy in front of it.

## Host

| Hostname        | IP              |
|-----------------|-----------------|
| vault.taylor.lan | 192.168.50.13  |

## Architecture

- **Vault binary** installed from the official HashiCorp release zip to `/usr/local/bin/vault`.
- **Storage backend**: integrated Raft (single-node; no external dependencies).
- **Listener**: `127.0.0.1:8200` (loopback only; Nginx handles external traffic).
- **Nginx** reverse-proxies port 80 (and optionally 443) → `127.0.0.1:8200`.
- **UI** is enabled and served through the Nginx proxy at `http://vault.taylor.lan`.

```
Client → Nginx :80 / :443 → localhost:8200 (Vault)
```

## Role Variables

Key variables (see `defaults/main.yaml` for full list):

| Variable | Default | Description |
|---|---|---|
| `vault_version` | `1.19.2` | Vault release version to install |
| `vault_proxy_server_name` | `vault.taylor.lan` | Nginx server_name |
| `vault_proxy_tls_enabled` | `false` | Enable HTTPS on Nginx |
| `vault_proxy_tls_force_https` | `false` | Redirect HTTP → HTTPS |
| `vault_proxy_tls_cert_path` | `/certs/vault.crt` | Cert path inside Nginx (host-mounted) |
| `vault_proxy_tls_key_path` | `/certs/vault.key` | Key path inside Nginx (host-mounted) |
| `vault_proxy_certs_dir` | `/opt/vault-proxy/certs` | Host directory for TLS certs |
| `vault_api_addr` | `http://vault.taylor.lan` | Vault's advertised API address |

## Using the Step CA for TLS (Recommended)

The project already has a Step CA at `certs.taylor.lan` (`192.168.50.9`).  
You can obtain a TLS certificate for Vault from it. No extra infrastructure is needed.

### Option A — Manual one-time cert issuance (simplest)

Run these commands on the Vault host (`192.168.50.13`) after the playbook:

```bash
# Install step CLI if not present
curl -L https://dl.step.sm/gh-release/cli/gh-release-header/v0.28.3/step_linux_0.28.3_amd64.tar.gz | tar xz -C /tmp
sudo mv /tmp/step_0.28.3/bin/step /usr/local/bin/

# Bootstrap trust for the CA
step ca bootstrap --ca-url https://certs.taylor.lan --fingerprint <CA_FINGERPRINT>

# Provision cert (valid 90 days; renew as needed)
sudo step ca certificate vault.taylor.lan \
    /opt/vault-proxy/certs/vault.crt \
    /opt/vault-proxy/certs/vault.key \
    --ca-url https://certs.taylor.lan \
    --provisioner acme  # or use your JWKS provisioner name
sudo chown root:root /opt/vault-proxy/certs/vault.{crt,key}
sudo chmod 640 /opt/vault-proxy/certs/vault.key
```

Then enable TLS in your vault host vars:

```yaml
vault_proxy_tls_enabled: true
vault_proxy_tls_force_https: true
vault_api_addr: "https://vault.taylor.lan"
```

Re-run the playbook to apply.

### Option B — Automated renewal via `step-ca` systemd timer

Create a systemd timer on the Vault host that runs `step ca renew` before cert expiry.  
The step-ca role README documents the renewal pattern. Document the chosen approach in `MEMORY.md` once confirmed.

### Finding the CA fingerprint

On the CA host (`192.168.50.9`):

```bash
step certificate fingerprint $(step path)/certs/root_ca.crt
```

## Vault Init and Unseal (Required After First Deploy)

HashiCorp Vault starts in an **uninitialized and sealed** state on first run.  
The playbook detects this and prints a reminder, but **these steps must be done manually**.

### 1. Initialize Vault

SSH to the Vault host:

```bash
ssh 192.168.50.13
export VAULT_ADDR=http://127.0.0.1:8200

vault operator init -key-shares=5 -key-threshold=3
```

**Save the 5 unseal keys and the initial root token somewhere safe** (password manager, printed paper, etc).  
These cannot be recovered if lost.

### 2. Unseal Vault

Provide 3 of the 5 unseal keys (one at a time):

```bash
vault operator unseal  # run 3 times with different keys
```

### 3. Verify

```bash
vault status
vault login  # use root token
```

The Vault UI will be accessible at `http://vault.taylor.lan` once Nginx is running.

### Subsequent Reboots

Vault is **sealed on every restart**. You must run `vault operator unseal` (3 times) after every reboot.  
If automated unseal is required, consider configuring [Transit Auto-Unseal](https://developer.hashicorp.com/vault/docs/configuration/seal/transit) or [AWS KMS](https://developer.hashicorp.com/vault/docs/configuration/seal/awskms) later.

## Ansible Vault Secrets

No secrets are required in Ansible Vault to deploy the Vault binary itself.  
If TLS cert provisioning is automated in a future task, the provisioner password or ACME account key may need to go into `vars/common/secrets.yaml`.

## Running the Playbook

From the Ansible host (`192.168.50.11`):

```bash
cd ~/ansible
ansible-playbook vault.yaml --vault-password-file ~/avpass
```

To target a different host:

```bash
ansible-playbook vault.yaml -e target=192.168.50.13 --vault-password-file ~/avpass
```

## Directory Layout

```
roles/vault/
├── README.md
├── defaults/
│   └── main.yaml          # All role variables with defaults
├── handlers/
│   └── main.yaml          # systemd reload/restart handlers
├── tasks/
│   └── main.yaml          # Install, configure, proxy, verify
└── templates/
    ├── vault.hcl.j2       # Vault server configuration
    ├── vault.service.j2   # systemd unit
    └── nginx.conf.j2      # Nginx reverse proxy
```

## Upgrading Vault

Update `vault_version` in `defaults/main.yaml` (or host vars), then re-run the playbook.  
The role compares the installed version string and only re-downloads when versions differ.

> **Note**: Always check the [Vault upgrade guide](https://developer.hashicorp.com/vault/docs/upgrading) before changing major versions.
