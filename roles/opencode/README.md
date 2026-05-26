# opencode role

Sets up a dedicated OpenCode AI coding assistant VM with a full developer toolchain.

## What it installs

| Tool | Method | Default version |
|------|--------|----------------|
| Go | `ppa:longsleep/golang-backports` | latest |
| Python / uv | direct binary download | 0.7.8 |
| Node.js LTS | NVM | lts/* (22.x) |
| Node.js latest | NVM | node (24.x+) |
| npm | updated after Node install | latest |
| Java (Temurin) | SDKMAN | 21.0.7-tem |
| Groovy | SDKMAN | 4.0.24 |
| Gradle | SDKMAN | 8.14.1 |
| Maven | SDKMAN | 3.9.9 |
| OpenCode CLI | npm (global) | latest |

All SDK-managed tools are installed under the `opencode` service user only.

## Prerequisites

- `vault_opencode_github_ssh_private_key` and `vault_opencode_github_ssh_public_key` in Vault at `secret/infra/opencode/github-ssh-key`
- Vault lookup configured via `vars/vault-secrets.yaml`
- VM reachable in the `opencode` inventory group

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
| `opencode_nvm_version` | `0.40.3` | NVM release to install |
| `opencode_java_version` | `21.0.7-tem` | SDKMAN Java version identifier |
| `opencode_install_cli` | `true` | Install `opencode` npm package |

## Updating SDK tool versions

Override in your playbook or host/group vars:

```yaml
opencode_java_version: "21.0.7-tem"
opencode_gradle_version: "8.14.1"
opencode_nvm_version: "0.40.3"
```
