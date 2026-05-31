# k3s-bootstrap role

Bootstraps the K3s cluster platform layer before GitOps takes over.

Runs on the first control-plane server after `k3s-cluster.yaml` completes.

## What it installs

In order:

1. **cert-manager** — CRD + operator for in-cluster TLS certificate management
2. **Step-CA trust bundle** — root CA ConfigMap in `kube-system` so pods can trust internal TLS
3. **cert-manager CA ClusterIssuer** — uses the step-ca intermediate cert/key to sign cluster certificates
4. **ArgoCD** — GitOps controller; runs in insecure mode (TLS terminated at the Traefik ingress)
5. **ESO (External Secrets Operator)** — pulls secrets from HashiCorp Vault into K8s Secrets
6. **ESO ClusterSecretStore** — points ESO at `vault.taylor.lan` using AppRole auth
7. **ArgoCD ingress + TLS cert** (optional) — cert-manager Certificate + Traefik Ingress
8. **ArgoCD root Application** — hands cluster management to the GitOps repo

After bootstrap, ArgoCD manages everything else (External DNS, workloads, etc.) using ESO
ExternalSecrets for any secrets those apps need.

## Required vault-backed variables

### `vars/common/secrets.yaml` (on Ansible host)

| Variable | Description |
|---|---|
| `vault_eso_role_id` | ESO Vault AppRole role_id (created by `vault-configure.yaml`) |
| `vault_eso_secret_id` | ESO Vault AppRole secret_id (created by `vault-configure.yaml`) |
| `vault_step_ca_intermediate_key` | Decrypted PEM private key for the step-ca intermediate CA |

#### Obtaining `vault_step_ca_intermediate_key`

```bash
ssh jason@192.168.50.9
sudo step crypto key format --pem /etc/step/secrets/intermediate_ca_key
# Enter the CA password (vault_step_ca_password) when prompted
# Paste the -----BEGIN EC PRIVATE KEY----- output into vars/common/secrets.yaml
```

### `vars/<env>/secrets.yaml` (on Ansible host)

| Variable | Description |
|---|---|
| `vault_argocd_gitops_repo_ssh_private_key` | SSH deploy key for the `homelab-k3s` GitOps repo |

## Non-secret variables (in `vars/<env>/vars.yaml`)

| Variable | Description |
|---|---|
| `k3s_argocd_gitops_repo_url` | GitOps repo SSH URL |
| `k3s_argocd_bootstrap_path` | Path in repo for this environment (e.g. `clusters/dev`) |
| `k3s_argocd_bootstrap_app_name` | Name for the root ArgoCD Application |
| `k3s_argocd_gitops_repo_target_revision` | Branch or tag (default `main`) |

### Optional ingress variables

| Variable | Default | Description |
|---|---|---|
| `k3s_argocd_ingress_enabled` | `false` | Enable ArgoCD Ingress |
| `k3s_argocd_ingress_host` | `""` | Hostname (e.g. `argocd.dev.lab`) |
| `k3s_argocd_ingress_class_name` | `traefik` | IngressClass |
| `k3s_argocd_ingress_entrypoints` | `websecure` | Traefik entrypoint |
| `k3s_argocd_ingress_tls` | `true` | Issue TLS cert via cert-manager |
| `k3s_argocd_tls_secret_name` | `argocd-server-tls` | Secret name for TLS cert |

### Key version variables

| Variable | Default |
|---|---|
| `k3s_argocd_version` | `v2.14.8` |
| `k3s_certmanager_version` | `v1.20.2` |
| `k3s_eso_version` | `v2.5.0` |

## Playbook usage

```bash
ansible-playbook -i inventory.ini k3s-bootstrap.yaml -e env=dev --vault-password-file ~/avpass
ansible-playbook -i inventory.ini k3s-bootstrap.yaml -e env=stage --vault-password-file ~/avpass
ansible-playbook -i inventory.ini k3s-bootstrap.yaml -e env=prod --vault-password-file ~/avpass
```

## Post-bootstrap verification

```bash
# cert-manager pods running
sudo k3s kubectl -n cert-manager get pods

# ClusterIssuer ready
sudo k3s kubectl get clusterissuer step-ca-issuer

# ArgoCD pods running
sudo k3s kubectl -n argocd get pods

# ESO pods running
sudo k3s kubectl -n external-secrets get pods

# ClusterSecretStore synced
sudo k3s kubectl get clustersecretstore vault-backend

# ArgoCD admin password
sudo k3s kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Root Application syncing
sudo k3s kubectl -n argocd get applications
```

## ESO usage after bootstrap

All GitOps-managed apps should use `ExternalSecret` resources that reference the
`vault-backend` ClusterSecretStore. Example:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: external-dns-tsig
  namespace: external-dns
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: external-dns-tsig
  data:
    - secretKey: tsig-secret
      remoteRef:
        key: secret/k3s/dev/external-dns-tsig
        property: value
```

Vault KV paths used by this cluster should be under `secret/k3s/<env>/`.

## Re-running bootstrap (idempotency)

The playbook is safe to re-run. `kubectl apply` is idempotent for all resources.
If the ArgoCD `argocd-cmd-params-cm` patch changes, the argocd-server deployment
is automatically rolled out to pick it up.
