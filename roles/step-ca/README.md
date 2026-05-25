# step-ca Role

Provision and operate a Smallstep Certificate Authority on hosts in the `step_ca` inventory group.

This role is intended for internal homelab PKI usage (non-public DNS) and is configured for:

- DNS server: `192.168.50.53` (`dns.taylor.lan`)
- step-ca host FQDN: `certs.taylor.lan`
- step-ca version: 0.30.2

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

## Issuing Certificates

All cert issuance must run **on the certs server** as the `step` system user. SSH to `192.168.50.9` first.

The provisioner password is stored in `vars/common/secrets.yaml` as `vault_step_ca_provisioner_password`.

### Standard Single-Domain Certificate

```bash
sudo -u step env STEPPATH=/etc/step HOME=/var/lib/step \
  step ca certificate myservice.taylor.lan /tmp/myservice.crt /tmp/myservice.key \
  --ca-url https://certs.taylor.lan \
  --root /etc/step/certs/root_ca.crt \
  --provisioner admin \
  --not-after 8760h
```

Enter the provisioner password when prompted, or pipe it:

```bash
echo 'YOUR_PROVISIONER_PASSWORD' | sudo -u step env STEPPATH=/etc/step HOME=/var/lib/step \
  step ca certificate myservice.taylor.lan /tmp/myservice.crt /tmp/myservice.key \
  --ca-url https://certs.taylor.lan \
  --root /etc/step/certs/root_ca.crt \
  --provisioner admin \
  --not-after 8760h \
  --provisioner-password-file /dev/stdin
```

### Wildcard / Multi-SAN Certificate

Use `--san` flags to add additional Subject Alternative Names beyond the primary CN. The primary
argument becomes the first SAN; each `--san` adds another.

```bash
sudo -u step env STEPPATH=/etc/step HOME=/var/lib/step \
  step ca certificate "*.taylor.lan" /tmp/wildcard.crt /tmp/wildcard.key \
  --ca-url https://certs.taylor.lan \
  --root /etc/step/certs/root_ca.crt \
  --provisioner admin \
  --san "*.dev.lab" \
  --san "*.stage.lab" \
  --san "*.prod.lab" \
  --not-after 8760h
```

This produces a single cert covering `*.taylor.lan`, `*.dev.lab`, `*.stage.lab`, and `*.prod.lab`.

### Changing the Expiry Window

Pass any duration to `--not-after`. The step-ca default is 24 hours.

| Duration | Flag value |
|----------|------------|
| 24 hours (default) | `--not-after 24h` |
| 90 days | `--not-after 2160h` |
| 1 year | `--not-after 8760h` |
| Specific date | `--not-after 2027-05-24T00:00:00Z` |

The root CA itself is valid until 2036-05-11. Do not issue leaf certs that outlive it.

### Inspect a Certificate

```bash
step certificate inspect /tmp/wildcard.crt
```

### Verify Against the Root CA

```bash
step certificate verify /tmp/wildcard.crt --roots /etc/step/certs/root_ca.crt
```

### Storing Certs in Vault

After issuance, push to Vault for use by External Secrets Operator. SSH to the certs server and run:

```bash
sudo python3 - << 'EOF'
import urllib.request, json, ssl

with open('/tmp/wildcard.crt') as f:
    crt = f.read()
with open('/tmp/wildcard.key') as f:
    key = f.read()

payload = json.dumps({"data": {"tls.crt": crt, "tls.key": key}}).encode()
req = urllib.request.Request(
    "http://192.168.50.13/v1/secret/data/k3s/wildcard-tls",
    data=payload,
    headers={
        "X-Vault-Token": "YOUR_VAULT_TOKEN",
        "Content-Type": "application/json",
    },
    method="POST",
)
with urllib.request.urlopen(req) as resp:
    print(resp.status, resp.read().decode())
EOF
```

The wildcard cert for `*.taylor.lan / *.dev.lab / *.stage.lab / *.prod.lab` is stored at
`secret/k3s/wildcard-tls` (KV v2). ESO can read all paths under `secret/k3s/*`.

---

## Installing the Root CA on Clients

The root CA certificate is at `/etc/step/certs/root_ca.crt` on the certs server.
Fingerprint: `b9ffe3b00644c2d10ec4287457ab194cf7bbfe56cce39ec6b66d1ffecc0e6bc6`

Pull it to your local machine first:

```bash
ssh 192.168.50.9 "sudo cat /etc/step/certs/root_ca.crt" > /tmp/taylor-lan-root-ca.crt
```

### Linux — Ubuntu / Debian (system-wide)

```bash
sudo cp /tmp/taylor-lan-root-ca.crt /usr/local/share/ca-certificates/taylor-lan-root-ca.crt
sudo update-ca-certificates
```

Verify: `grep -r "taylor" /etc/ssl/certs/ca-certificates.crt | head -1` (should not be empty).

**For managed Ubuntu VMs**, use the `trust-ca` Ansible role instead of doing this manually —
see the root `README.md` for the playbook command.

### Linux — Arch / CachyOS (system-wide)

```bash
sudo cp /tmp/taylor-lan-root-ca.crt /etc/ca-certificates/trust-source/anchors/taylor-lan-root-ca.crt
sudo trust extract-compat
```

Verify: `trust list | grep -i taylor`

### macOS (system-wide)

```bash
sudo security add-trusted-cert \
  -d -r trustRoot \
  -k /Library/Keychains/System.keychain \
  /tmp/taylor-lan-root-ca.crt
```

Or import via Keychain Access GUI:
1. Open **Keychain Access** → select **System** keychain
2. File → Import Items → select `taylor-lan-root-ca.crt`
3. Double-click the imported cert → **Trust** → set "When using this certificate" to **Always Trust**
4. Close and authenticate

Safari and Chrome on macOS use the system keychain. Firefox requires the separate step below.

### Windows (system-wide)

Open PowerShell **as Administrator**:

```powershell
certutil -addstore Root C:\path\to\taylor-lan-root-ca.crt
```

Or via the GUI:
1. Press Win+R → `mmc` → Enter
2. File → Add/Remove Snap-in → Certificates → Computer Account → Local Computer
3. Expand **Trusted Root Certification Authorities** → Certificates
4. Right-click → All Tasks → Import → follow the wizard

Edge and Chrome on Windows use the system certificate store. Firefox requires the separate step below.

### Firefox (all platforms)

Firefox maintains its own certificate store and does not use the OS trust store.

1. Open **Settings** → **Privacy & Security** → scroll to **Certificates**
2. Click **View Certificates** → **Authorities** tab
3. Click **Import** → select `taylor-lan-root-ca.crt`
4. Check **Trust this CA to identify websites** → OK
5. Restart Firefox

---

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
- The provisioner password file (`prov-password`) is written and removed on every re-run, causing
  a spurious `changed` on idempotent runs. This is cosmetic and does not affect service state.
