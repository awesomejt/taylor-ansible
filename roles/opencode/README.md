# opencode role

Sets up a dedicated OpenCode AI coding assistant VM with a full developer
toolchain, a managed OpenCode runtime config, and optional workflow/orchestrator
deployment from the Ansible control host.

## What it installs

| Tool | Method | Default version |
|------|--------|----------------|
| Go | `ppa:longsleep/golang-backports` | latest |
| Python / uv | direct binary download | 0.11.16 |
| Node.js LTS | NVM | `lts/*` |
| Node.js latest | NVM | `node` |
| npm | updated after Node install | latest |
| Java (Temurin) | SDKMAN | 25.0.3-tem |
| Groovy | SDKMAN | 5.0.6 |
| Gradle | SDKMAN | 9.5.1 |
| Maven | SDKMAN | 3.9.16 |
| OpenCode CLI | npm package `opencode-ai` | latest |
| AWB CLI | copied from controller | pinned by source binary |
| agent-orchestrator | copied from controller | pinned by source checkout |

All SDK-managed tools are installed under the `opencode` service user only.

## Prerequisites

- `vault_opencode_github_ssh_private_key` and `vault_opencode_github_ssh_public_key` in Vault at `secret/infra/opencode/github-ssh-key`
- Vault lookup configured via `vars/vault-secrets.yaml`
- VM reachable in the `opencode` inventory group
- If deploying the workflow bundle, set `opencode_controller_workflows_bundle_dir`
   to a rendered OpenCode bundle on the Ansible control host.
- If deploying `agent-orchestrator`, set
   `opencode_controller_agent_orchestrator_source_dir` to the checked-out
   repository on the Ansible control host.
- If deploying the AWB CLI, set `opencode_controller_awb_bin_path` to a built
   `awb` binary on the Ansible control host.

## Adding the GitHub deploy key

The RSA 4096 keypair is generated once and stored in Vault. To register it with GitHub:

1. Copy the public key from Vault:
   ```bash
   vault kv get -field=public_key secret/infra/opencode/github-ssh-key
   ```
2. Go to GitHub → Settings → SSH and GPG keys → New SSH key (for account-wide access), or
   on the repository → Settings → Deploy keys → Add deploy key (read-only or write access).

## Key variables

| Variable | Default | Description |
|----------|---------|-------------|
| `opencode_user` | `opencode` | Service user |
| `opencode_git_user_name` | `OpenCode Agent` | Git commit name |
| `opencode_git_user_email` | `opencode@taylor.lan` | Git commit email |
| `opencode_nvm_version` | `0.40.4` | NVM release to install |
| `opencode_java_version` | `25.0.3-tem` | SDKMAN Java version identifier |
| `opencode_install_cli` | `true` | Install `opencode` npm package |
| `opencode_manage_workflows_bundle` | `false` | Copy a rendered OpenCode bundle from the controller |
| `opencode_install_awb_cli` | `false` | Copy a built `awb` binary from the controller |
| `opencode_install_agent_orchestrator` | `false` | Copy and install `agent-orchestrator` from the controller |
| `opencode_web_service_enabled` | `true` | Manage a local `opencode web` systemd service |

## Updating SDK tool versions

Override in your playbook or host/group vars:

```yaml
opencode_java_version: "25.0.3-tem"
opencode_gradle_version: "9.5.1"
opencode_nvm_version: "0.40.4"
```

## Deploying the worker runtime

The role can install three controller-provided artifacts in addition to the base
toolchain:

- a rendered OpenCode bundle into `~/.config/opencode/`
- a built `awb` CLI into `~/.local/bin/awb`
- a copied `agent-orchestrator` checkout plus installed launcher commands

Example apply from the Ansible control host:

```bash
ansible-playbook -i inventory.ini opencode.yaml \
   --vault-password-file ~/avpass \
   -e opencode_manage_workflows_bundle=true \
   -e opencode_controller_workflows_bundle_dir=/home/jason/workflows/.build/final2-opencode-server/opencode \
   -e opencode_install_awb_cli=true \
   -e opencode_controller_awb_bin_path=/home/jason/agent-workbench/cli/builds/awb \
   -e opencode_install_agent_orchestrator=true \
   -e opencode_controller_agent_orchestrator_source_dir=/home/jason/agent-orchestrator
```

The managed web service is intentionally local-only by default
(`127.0.0.1:4096`). Expose it more broadly only after choosing an authentication
strategy and setting `opencode_server_password`.
