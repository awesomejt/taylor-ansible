# k3s-bootstrap role

Bootstraps Argo CD and SOPS support on an existing K3s cluster.

This role is intended to run only after the base cluster is installed and reachable.

## What it does

- Installs Argo CD into the `argocd` namespace
- Creates Argo CD repository credentials from vault SSH private key
- Creates a Kubernetes secret containing an age private key for SOPS decryption
- Enables kustomize exec plugins and patches `argocd-repo-server` with KSOPS support
- Optionally creates Argo CD ingress
- Creates the root Argo CD `Application` for App of Apps bootstrap

## Required variables

Vault-backed variables (for example in `vars/<env>/secrets.yaml`):

- `vault_argocd_gitops_repo_ssh_private_key`
- `vault_sops_age_key`

Non-secret variables (for example in `vars/<env>/vars.yaml`):

- `k3s_argocd_gitops_repo_url`
- `k3s_argocd_bootstrap_path`
- `k3s_argocd_bootstrap_app_name`
- `k3s_argocd_gitops_repo_target_revision`

Optional ingress variables:

- `k3s_argocd_ingress_enabled`
- `k3s_argocd_ingress_host`
- `k3s_argocd_ingress_class_name`
- `k3s_argocd_ingress_entrypoints`
- `k3s_argocd_ingress_tls`

Optional KSOPS variables:

- `k3s_argocd_ksops_download_url` (override for non-x86_64 nodes, for example arm64 release tarball URL)

## Playbook usage

```bash
ansible-playbook -i inventory.ini k3s-bootstrap.yaml -e env=stage --ask-vault-pass
ansible-playbook -i inventory.ini k3s-bootstrap.yaml -e env=prod --ask-vault-pass
```
