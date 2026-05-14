# step-ca Role

Provision and operate a Smallstep Certificate Authority on hosts in the `step_ca` inventory group.

This role is intended for internal homelab PKI usage (non-public DNS) and is configured for:

- DNS server: `192.168.50.53` (`dns.taylor.lan`)
- step-ca host FQDN: `certs.taylor.lan`

## What Is Automated

When `step_ca_auto_init: true` and required vaulted secrets are present, the role automates:

- Base package installation (`curl`, `gpg`, `ca-certificates`, `openssl`)
- `step` system user/group creation
- Step directories creation (`/var/lib/step`, `/etc/step`)
- step-cli installation via Smallstep apt repository (if not already installed)
- step-ca daemon package installation via Smallstep apt repository
- Non-interactive `step ca init`
- Systemd unit deployment and daemon reload
- Service enable/start (`step-ca`)
- Cleanup of temporary provisioner password file
- Persistent runtime password file at `/etc/step/password.txt` for unattended starts

## Required Vault Secrets

Store these in `vars/common/secrets.yaml` on the Ansible host and encrypt with Ansible Vault:

- `vault_step_ca_password`: CA key password
- `vault_step_ca_provisioner_password`: default provisioner password
- `vault_step_ca_admin_email`: admin email metadata (placeholder for future use)

Sanitized placeholders are already present in `vars/common/example-secrets.yaml`.

## Apply Workflow (From Control Host 192.168.50.11)

Do not run production-effecting playbook execution from this local workstation.

1. Sync from local repo to Ansible host:

```bash
./sync-to-ansible.sh
```

2. SSH to control host:

```bash
ssh 192.168.50.11
cd ~/ansible
```

3. Ensure vault secrets exist:

```bash
ansible-vault edit vars/common/secrets.yaml --vault-password-file ~/avpass
```

4. Run playbook:

```bash
ansible-playbook -i inventory.ini step-ca.yml --vault-password-file ~/avpass
```

5. Validate CA service:

```bash
ansible step_ca -i inventory.ini -b -m shell -a 'systemctl is-enabled step-ca && systemctl is-active step-ca'
ansible step_ca -i inventory.ini -b -m shell -a 'step version && step ca health --ca-url https://certs.taylor.lan:443'
```

## Manual Steps Still Required

1. Back up CA material immediately after first successful initialization:

- `/var/lib/step`
- `/etc/step`

Keep offline, encrypted backups. Loss of CA keys means certificate trust cannot be recovered.

2. Confirm internal DNS resolution from clients:

```bash
nslookup certs.taylor.lan 192.168.50.53
```

3. Ensure network policy/firewall allows client access to `certs.taylor.lan:443`.

4. Treat `/etc/step/password.txt` as sensitive material and include it in your
	secret-handling and backup procedures.

## Idempotency Notes

- If `/etc/step/certs/root_ca.crt` exists, init is skipped.
- Re-runs keep service enabled and running.
- Temporary init password files are removed at end of successful runs.
