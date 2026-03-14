# taylor-ansible

Ansible playbooks and roles for homelab hosts.

## Playbooks

Run system updates on all managed servers:

```bash
ansible-playbook -i inventory.ini upgrade-all.yaml
```

Run Technitium DNS setup against hosts in the `dns` inventory group:

```bash
ansible-playbook -i inventory.ini dns.yaml
```

The DNS role installs Technitium DNS Server. Zone and record management is optional and disabled by default. See `roles/technitium-dns/README.md` and `examples/dns-setup-example.yaml` for details on enabling automated DNS zone management, including RFC2136 update ACLs for ExternalDNS.

Run K3s cluster setup for prod (HA):

```bash
ansible-playbook -i inventory.ini k3s-cluster.yaml -e env=prod --ask-vault-pass
```

Run K3s cluster setup for stage:

```bash
ansible-playbook -i inventory.ini k3s-cluster.yaml -e env=stage --ask-vault-pass
```

K3s requirements:

- Define hosts in inventory groups: `k3s_prod_servers`, `k3s_prod_agents`, `k3s_stage_servers`, and `k3s_stage_agents`.
- Set `vault_k3s_token` in `vars/<env>/secrets.yaml`.
- Set `k3s_registration_address` in `vars/<env>/vars.yaml` to a stable DNS name or VIP used by joining servers/agents.
- Set `vault_argocd_gitops_repo_ssh_private_key` in `vars/<env>/secrets.yaml` so Argo CD can clone the GitOps repo over SSH.
- Set `k3s_argocd_gitops_repo_url` and `k3s_argocd_bootstrap_path` in `vars/<env>/vars.yaml` when you need to override the defaults.
- Set `vault_external_dns_rfc2136_tsig_keyname` and `vault_external_dns_rfc2136_tsig_secret` in `vars/<env>/secrets.yaml` so Ansible can seed the `external-dns-rfc2136` Kubernetes secret used by ExternalDNS.
- Optional: set `vault_external_dns_rfc2136_tsig_secret_alg` in `vars/<env>/secrets.yaml` (defaults to `hmac-sha256`).
- Prod HA validation expects at least 3 hosts in `k3s_prod_servers` when `k3s_prod_ha: true`.

Bootstrap behavior:

- Ansible installs K3s on the control-plane and agent nodes.
- Ansible optionally installs cert-manager.
- Ansible installs Argo CD, exposes it with ingress when configured, loads the GitOps repo SSH credential, and creates the root Argo CD application.
- Ansible seeds cluster secrets required before GitOps reconciliation (including ExternalDNS RFC2136 TSIG credentials).
- Argo CD then reconciles the environment path from the `homelab-k3s` repository using the App of Apps pattern.

Suggested workflow from this workstation:

```bash
./sync-to-ansible.sh
ssh jason@192.168.50.12
cd ~/ansible
ansible-playbook -i inventory.ini k3s-cluster.yaml -e env=stage --ask-vault-pass
```

You can swap `stage` for `prod` once the prod inventory and secrets are ready.

## Argo CD Access

If Argo CD ingress is enabled, browse to the configured host for that environment.

Stage is currently configured as:

```text
https://argocd-stage.taylor.lan
```

Retrieve the initial admin password from the first control-plane server:

```bash
sudo k3s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

If you use the Argo CD CLI through the ingress endpoint, use gRPC-web:

```bash
argocd login argocd-stage.taylor.lan --username admin --grpc-web
```

If ingress is disabled for an environment, use a port-forward instead:

```bash
sudo k3s kubectl -n argocd port-forward svc/argocd-server 8080:443
```

## GitOps Repo SSH Setup

Generate a dedicated deploy key for Argo CD:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/argocd-homelab-k3s -C "argocd-homelab-k3s" -N ""
```

Add `~/.ssh/argocd-homelab-k3s.pub` as a read-only deploy key on the GitHub repository.

Copy the private key into `vars/<env>/secrets.yaml`:

```yaml
vault_argocd_gitops_repo_ssh_private_key: |
	-----BEGIN OPENSSH PRIVATE KEY-----
	...
	-----END OPENSSH PRIVATE KEY-----
```

By default the bootstrap points Argo CD at:

```text
git@github.com:awesomejt/homelab-k3s.git
```

The corresponding root application paths are:

- `clusters/stage`
- `clusters/prod`

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