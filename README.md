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

The AI stack deploys Open WebUI, LiteLLM, Ollama, AnythingLLM, n8n, Qdrant, SearXNG, and Valkey on the same VM.
Secrets for this stack are loaded from vars/common/secrets.yaml on the control host, with vars/common/example-secrets.yaml as the fallback template.

Run OpenClaw setup against hosts in the `openclaw` inventory group:

```bash
ansible-playbook -i inventory.ini openclaw.yaml
```

The OpenClaw playbook follows the project role pattern and uses:

- `roles/openclaw/tasks/main.yaml`
- `roles/openclaw/defaults/main.yaml`

Override role defaults with `-e` when needed.

Override the CLI npm package or setup command when needed:

```bash
ansible-playbook -i inventory.ini openclaw.yaml \
	-e openclaw_cli_npm_package=@your-org/openclaw-cli \
	-e 'openclaw_setup_command=openclaw install --yes --no-onboarding'
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