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

Local kubectl access (single cluster):

- On each K3s server, kubeconfig is at `/etc/rancher/k3s/k3s.yaml`.
- Copy it to your workstation, then update the server endpoint to a reachable host/IP.

Example:

```bash
scp jason@192.168.50.14:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-stage.yaml
```

Then edit `~/.kube/k3s-stage.yaml` and set:

```yaml
clusters:
- cluster:
		server: https://k3s-stage-server.stage.lab:6443
```

or use a reachable IP/FQDN for your network.

Local kubectl access (multiple clusters):

- Keep one kubeconfig file per environment, for example:

- `~/.kube/k3s-dev.yaml`
- `~/.kube/k3s-stage.yaml`
- `~/.kube/k3s-prod.yaml`

- Merge them into your default kubeconfig:

```bash
KUBECONFIG=~/.kube/k3s-dev.yaml:~/.kube/k3s-stage.yaml:~/.kube/k3s-prod.yaml \
	kubectl config view --flatten > ~/.kube/config
chmod 600 ~/.kube/config
```

- Rename contexts to stable names (recommended):

```bash
kubectl config get-contexts
kubectl config rename-context default k3s-dev
kubectl config rename-context default-1 k3s-stage
kubectl config rename-context default-2 k3s-prod
```

If your context names are different, rename accordingly.

Using contexts:

- List contexts:

```bash
kubectl config get-contexts
```

- Switch active cluster:

```bash
kubectl config use-context k3s-stage
```

- Verify current cluster:

```bash
kubectl config current-context
kubectl get nodes
```

Optional shell helper:

- Add aliases for quick switching:

```bash
alias kctx='kubectl config use-context'
alias kcur='kubectl config current-context'
```

Troubleshooting kubectl connectivity:

- Symptom: `Unable to connect to the server` or timeout.

Checks:

```bash
kubectl config current-context
kubectl config view --minify
nc -vz <k3s-server-host-or-ip> 6443
```

If port `6443` is not reachable, fix DNS, routing, firewall, or VPN first.

- Symptom: x509 error after copying kubeconfig, for example:

```text
x509: certificate is valid for 127.0.0.1, ... not <your-hostname>
```

Cause:

- The kubeconfig `server:` address does not match a TLS SAN on the K3s server certificate.

Fix option 1 (recommended): use a SAN that already exists in the cert.

- In your local kubeconfig, set `clusters[].cluster.server` to a name/IP that is already in the server certificate SAN list.

Quick inspect from a server:

```bash
sudo k3s kubectl get node -o wide
sudo openssl x509 -in /var/lib/rancher/k3s/server/tls/serving-kube-apiserver.crt -text -noout | grep -A1 "Subject Alternative Name"
```

Fix option 2: reissue cert with the correct SAN.

- Add the desired endpoint(s) in your Ansible vars as TLS SANs, for example in `vars/<env>/vars.yaml`:

```yaml
k3s_server_tls_sans:
	- "k3s-stage-server.stage.lab"
	- "192.168.50.14"
```

- Re-run the K3s playbook for that environment:

```bash
ansible-playbook -i inventory.ini k3s-cluster.yaml -e env=stage --ask-vault-pass
```

Then update local kubeconfig `server:` to one of those SAN values.

- Symptom: context exists but points to wrong cluster.

Checks:

```bash
kubectl config get-contexts
kubectl config use-context k3s-stage
kubectl cluster-info
kubectl get nodes -o wide
```

If node names/environment do not match expectations, switch to the intended context.

- Last-resort temporary bypass (not recommended for normal use):

```bash
kubectl --insecure-skip-tls-verify=true get nodes
```

Use this only for quick diagnosis; fix SAN/certificate alignment instead.
