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

Run the AI stack setup against hosts in the `ai_stack` inventory group:

```bash
ansible-playbook -i inventory.ini openwebui.yaml
```

Run the Open WebUI web-memory ingestion stack (Open WebUI prompt-derived queries -> SearXNG crawl -> PostgreSQL metadata + Qdrant vectors):

```bash
ansible-playbook -i inventory.ini web-memory.yaml --vault-password-file ~/avpass
```

The AI stack deploys Open WebUI, LiteLLM, Ollama, AnythingLLM, n8n, Qdrant, SearXNG, and Valkey on the same VM.
Secrets for this stack are loaded from vars/common/secrets.yaml on the control host, with vars/common/example-secrets.yaml as the fallback template.
Open WebUI is configured for LDAP login against LLDAP in this repo's open-source/default deployment path.
n8n LDAP is not enabled here because upstream docs mark LDAP as a Business/Enterprise feature.

OpenClaw automation is currently dormant (kept for future use). See `archive/README.md` for archive workflow and `archive/openclaw.md` for current status/reactivation notes.

Legacy Docker Distribution registry automation is now hard-archived at `archive/playbooks/registry.yaml` and `archive/roles/registry/`.
Harbor is now the primary registry deployment path.

Run Prometheus, Grafana, pgAdmin, and Portainer on the consolidated Docker host:

```bash
ansible-playbook -i inventory.ini prometheus.yaml
ansible-playbook -i inventory.ini grafana.yaml --ask-vault-pass
ansible-playbook -i inventory.ini pgadmin.yaml --ask-vault-pass
ansible-playbook -i inventory.ini portainer.yaml
```

Grafana and pgAdmin are now configured to support LDAP login against LLDAP (`ldap://lldap:3890`) with internal/local auth fallback retained.

Run Kanban (Vikunja) on the consolidated Docker host:

```bash
ansible-playbook -i inventory.ini kanban.yaml --ask-vault-pass
```

Run LDAP (LLDAP role) on the consolidated Docker host:

```bash
ansible-playbook -i inventory.ini ldap.yaml --vault-password-file ~/avpass
```

Run Harbor on the consolidated Docker host (with PostgreSQL provisioning on `postgres_prod`):

```bash
ansible-playbook -i inventory.ini harbor.yaml --vault-password-file ~/avpass
```

Harbor is routed through Traefik at `harbor.taylor.lan`. The local Harbor admin account (`admin`) is still required for bootstrap and break-glass access even when LDAP auth mode is enabled.

Or deploy all four through the aggregate inventory group:

```bash
ansible-playbook -i inventory.ini prometheus.yaml -e target=ops_stack
ansible-playbook -i inventory.ini grafana.yaml -e target=ops_stack --ask-vault-pass
ansible-playbook -i inventory.ini pgadmin.yaml -e target=ops_stack --ask-vault-pass
ansible-playbook -i inventory.ini portainer.yaml -e target=ops_stack
```

Run step-ca setup against hosts in the `step_ca` inventory group:

```bash
ansible-playbook -i inventory.ini step-ca.yml --vault-password-file ~/avpass
```

The step-ca role supports automated non-interactive initialization when vaulted
password variables are present. See `roles/step-ca/README.md` for full apply
workflow, validation commands, and remaining manual backup steps.

## Internal CA Trust

Install the internal root CA certificate (`certs.taylor.lan Root CA`) on all managed Ubuntu VMs:

```bash
ansible-playbook -i inventory.ini trust-ca.yaml
```

This distributes `/etc/step/certs/root_ca.crt` from the `step_ca` host into each VM's system trust store
(`/usr/local/share/ca-certificates/taylor-lan-root-ca.crt`) and runs `update-ca-certificates`.

Run this playbook when:
- Adding a new VM to the inventory (so internal HTTPS services resolve without `--cacert`)
- After rebuilding the step-ca server (new cert fingerprint requires re-distribution)

The role is idempotent — `update-ca-certificates` only runs if the cert file changes.

If hosts are unreachable due to stale SSH host keys (common after VM rebuilds), clear the old key first:

```bash
ssh-keygen -f ~/.ssh/known_hosts -R <ip>
ssh -o StrictHostKeyChecking=accept-new <ip> 'echo ok'
```

Then re-run the playbook. The wildcard TLS cert for `*.taylor.lan`, `*.dev.lab`, `*.stage.lab`, and
`*.prod.lab` is stored in Vault at `secret/k3s/wildcard-tls` (keys: `tls.crt`, `tls.key`) for use
by External Secrets Operator.

OpenClaw is hard-archived in `archive/playbooks/openclaw.yaml` and `archive/roles/openclaw/`; use the reactivation steps in `archive/openclaw.md` when needed.

The DNS role installs Technitium DNS Server. Zone and record management is optional and disabled by default. See `roles/technitium-dns/README.md` and `examples/dns-setup-example.yaml` for details on enabling automated DNS zone management, including RFC2136 update ACLs for ExternalDNS.

Run K3s cluster setup for prod (HA):

```bash
ansible-playbook -i inventory.ini k3s-cluster.yaml -e env=prod --ask-vault-pass
```

Run K3s cluster setup for stage:

```bash
ansible-playbook -i inventory.ini k3s-cluster.yaml -e env=stage --ask-vault-pass
```

Run Argo CD + SOPS bootstrap for prod:

```bash
ansible-playbook -i inventory.ini k3s-bootstrap.yaml -e env=prod --ask-vault-pass
```

Run Argo CD + SOPS bootstrap for stage:

```bash
ansible-playbook -i inventory.ini k3s-bootstrap.yaml -e env=stage --ask-vault-pass
```

K3s requirements:

- Define hosts in inventory groups: `k3s_prod_servers`, `k3s_prod_agents`, `k3s_stage_servers`, and `k3s_stage_agents`.
- Set `vault_k3s_token` in `vars/<env>/secrets.yaml`.
- Set `k3s_registration_address` in `vars/<env>/vars.yaml` to a stable DNS name or VIP used by joining servers/agents.
- Set `k3s_argocd_gitops_repo_url` and `k3s_argocd_bootstrap_path` in `vars/<env>/vars.yaml` when you need to override defaults used by bootstrap.
- Set `vault_argocd_gitops_repo_ssh_private_key` in `vars/<env>/secrets.yaml` so Argo CD can clone the GitOps repo over SSH.
- Set `vault_sops_age_key` in `vars/<env>/secrets.yaml` so Argo CD can decrypt SOPS-encrypted manifests.
- Optional: set `k3s_argocd_ingress_enabled` and related ingress variables in `vars/<env>/vars.yaml`.
- Prod HA validation expects at least 3 hosts in `k3s_prod_servers` when `k3s_prod_ha: true`.

Bootstrap behavior:

- `k3s-cluster.yaml` installs K3s on control-plane and agent nodes.
- `k3s-bootstrap.yaml` installs Argo CD on the first control-plane node, configures repo access over SSH, enables SOPS via KSOPS, and creates the root Argo CD application.
- Argo CD then reconciles the environment path from the `homelab-k3s` repository using the App of Apps pattern.
- Runtime application secrets should be managed through SOPS-encrypted manifests in the GitOps repository.

Suggested workflow from this workstation:

```bash
./sync-to-ansible.sh
ssh jason@192.168.50.12
cd ~/ansible
ansible-playbook -i inventory.ini k3s-cluster.yaml -e env=stage --ask-vault-pass
ansible-playbook -i inventory.ini k3s-bootstrap.yaml -e env=stage --ask-vault-pass
```

You can swap `stage` for `prod` once the prod inventory and secrets are ready.

## Post-Bootstrap Next Steps

After `k3s-bootstrap.yaml` completes successfully, verify that the bootstrap is working:

### 1. Verify Argo CD pods are running

```bash
sudo k3s kubectl -n argocd get pods
```

You should see at least 5 pods: `argocd-server`, `argocd-repo-server`, `argocd-controller-manager`, `argocd-redis`, etc. all in `Running` state.

### 2. Check the root Application sync status

```bash
sudo k3s kubectl -n argocd get applications
```

You should see a root application (typically `root-app` or matching `k3s_argocd_bootstrap_app_name`) with `Synced` status. It may take a minute or two after bootstrap to begin syncing.

### 3. Access the Argo CD UI

Retrieve the initial admin password:

```bash
sudo k3s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

If Argo CD ingress is configured, browse to the ingress hostname. Otherwise, use port-forward:

```bash
sudo k3s kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Then open `https://localhost:8080` (you'll need to accept the self-signed cert in the browser).

### 4. Add SOPS-encrypted secrets to the GitOps repository

Runtime application secrets (ExternalDNS TSIG, Grafana admin password, Harbor credentials, etc.) should be committed only as SOPS-encrypted manifests in the `homelab-k3s` repository.

Example workflow:

``` bash
cd ~/projects/homelab-k3s

# Create an encrypted secret for ExternalDNS RFC2136 TSIG
sops apps/infrastructure/external-dns-secret/base/secret.yaml
```

Then commit and push. Argo CD will automatically decrypt the secret using the age key seeded in the `argocd` namespace during bootstrap.

### 5. Bootstrap additional environments

Once dev (or stage) is working, run bootstrap on the next environment:

```bash
ansible-playbook -i inventory.ini k3s-bootstrap.yaml -e env=stage --ask-vault-pass
```

Then:

```bash
ansible-playbook -i inventory.ini k3s-bootstrap.yaml -e env=prod --ask-vault-pass
```

Each environment uses its own Git branch/path (controlled by `k3s_argocd_bootstrap_path` in `vars/<env>/vars.yaml`).

## Post-Setup Validation

Once all environments are bootstrapped and apps are converging, run the validation script:

```bash
./validate-k3s-post-setup.sh prod
```

For stage (or when apps are still converging), allow `Progressing` app health:

```bash
./validate-k3s-post-setup.sh stage --allow-progressing
```

The script validates:

- Kubernetes API connectivity and active context
- Argo CD app presence, sync, and health status
- `letsencrypt-lab` ClusterIssuer readiness
- Required seeded secrets for ExternalDNS, Grafana, and Reposilite
- Expected ingress hostnames
- Certificate readiness for monitoring and artifact ingress

## Argo CD Access

If Argo CD ingress is enabled, browse to the configured host for that environment.

Stage is currently configured as:

```text
https://argocd.stage.lab
```

Retrieve the initial admin password from the first control-plane server:

```bash
sudo k3s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

If you use the Argo CD CLI through the ingress endpoint, use gRPC-web:

```bash
argocd login argocd.stage.lab --username admin --grpc-web
```

Change the initial admin password after first login:

```bash
argocd account update-password --account admin
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

Add your age private key used for SOPS decryption in Argo CD:

```yaml
vault_sops_age_key: |
	# created with: age-keygen -o age.agekey
	# public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	AGE-SECRET-KEY-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
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