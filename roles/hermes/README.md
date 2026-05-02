# Hermes Agent (Nous Research) - Ansible Role

Ansible role for deploying [Hermes Agent by Nous Research](https://github.com/NousResearch/hermes-agent) — a Python-based AI agent that connects to messaging platforms (Telegram, Discord, Slack) and exposes a web dashboard.

**No pre-built Docker image exists.** This role clones the source repo and builds the image locally.

## Overview

The `hermes` role:
- Clones `https://github.com/NousResearch/hermes-agent.git` and builds a local Docker image
- Runs two Docker services: `gateway` (messaging platforms) and `dashboard` (web UI)
- Proxies the dashboard via Nginx at `hermes.taylor.lan` with HTTP Basic Auth
- Manages configuration as `config.yaml` and secrets as `.env` (both mounted to `/opt/data/` in containers)
- Manages the stack as a systemd service (`hermes.service`)

## Role Structure

```
roles/hermes/
├── defaults/
│   └── main.yaml               # Default variables
├── handlers/
│   └── main.yaml               # Restart and rebuild handlers
├── tasks/
│   ├── main.yaml               # Main task orchestration
│   └── install_docker.yaml     # Git clone + docker build
└── templates/
    ├── docker-compose.yaml.j2  # gateway + dashboard + nginx services
    ├── hermes.env.j2           # .env file (API keys, platform tokens)
    ├── hermes.config.j2        # config.yaml (model, terminal, agent settings)
    ├── nginx.conf.j2           # Nginx reverse proxy for dashboard
    └── hermes.service.j2       # Systemd unit
```

## Quick Start

```bash
# Syntax check
ansible-playbook --syntax-check hermes.yaml

# Dry run
ansible-playbook -i inventory.ini hermes.yaml --check

# Deploy
ansible-playbook -i inventory.ini hermes.yaml
```

### Inventory

```ini
[hermes]
192.168.50.92
```

## Required Secrets

Add to `vars/common/secrets.yaml` on the Ansible server (vault-encrypt this file):

```yaml
# REQUIRED - all LLM calls route through OpenRouter
# Get at: https://openrouter.ai/keys
vault_hermes_openrouter_api_key: "sk-or-..."

# REQUIRED if hermes_nginx_auth_enable: true (strongly recommended)
# Protects the dashboard, which stores your API keys
vault_hermes_dashboard_password: "your-strong-password"

# OPTIONAL - Telegram gateway
# vault_hermes_telegram_bot_token: ""

# OPTIONAL - Discord gateway
# vault_hermes_discord_token: ""

# OPTIONAL - Slack gateway (both required for Socket Mode)
# vault_hermes_slack_bot_token: ""
# vault_hermes_slack_app_token: ""
```

See `vars/common/example-secrets.yaml` for the full template.

## Key Configuration Variables

Override in `vars/common/vars.yaml` or your playbook's `vars:` block.

| Variable | Default | Description |
|---|---|---|
| `hermes_default_model` | `anthropic/claude-opus-4.6` | LLM model (OpenRouter format: `provider/model`) |
| `hermes_model_provider` | `auto` | Provider selection (`auto`, `openrouter`, `anthropic`, etc.) |
| `hermes_terminal_backend` | `docker` | Agent tool execution backend |
| `hermes_nginx_server_name` | `hermes.taylor.lan` | Hostname for the dashboard |
| `hermes_nginx_auth_enable` | `true` | Enable HTTP Basic Auth (strongly recommended) |
| `hermes_nginx_auth_user` | `admin` | Basic auth username |
| `hermes_telegram_enabled` | `false` | Enable Telegram gateway |
| `hermes_discord_enabled` | `false` | Enable Discord gateway |
| `hermes_slack_enabled` | `false` | Enable Slack gateway |
| `hermes_git_version` | `main` | Branch/tag to build from |

## Architecture

### Docker Services

**`gateway`** (`network_mode: host`)
- Connects outbound to Telegram, Discord, Slack, etc.
- Host networking is required for reliable platform connectivity
- Reads config and secrets from `/opt/data/` (mounted from `hermes_data_dir`)

**`dashboard`** (Docker bridge network `hermes_frontend`)
- Web UI at port `9119` — intentionally localhost-only by design
- Stores API keys and configuration — must be protected before exposing
- Proxied by Nginx with HTTP Basic Auth

**`nginx`** (bridge network `hermes_frontend`)
- Exposes dashboard at `hermes.taylor.lan`
- Adds HTTP Basic Auth (controlled by `hermes_nginx_auth_enable`)
- Optional SSL/TLS via `hermes_nginx_ssl_enable`

### File Paths on Host

| Path | Description |
|---|---|
| `hermes_install_dir` (`/opt/hermes`) | Source code, docker-compose, nginx.conf |
| `hermes_data_dir` (`/var/lib/hermes`) | `config.yaml`, `.env`, logs, memory, skills |

Both data dirs are bind-mounted into containers at `/opt/data`.

## Nginx Reverse Proxy

The dashboard is intentionally not exposed directly — the Nous Research docs explicitly warn to add authentication before exposing it. This role adds Nginx with HTTP Basic Auth by default.

To disable auth (not recommended):
```yaml
hermes_nginx_auth_enable: false
```

To enable SSL:
```yaml
hermes_nginx_ssl_enable: true
hermes_nginx_ssl_cert_path: /path/to/cert.pem
hermes_nginx_ssl_key_path: /path/to/key.pem
```

## Migrating from OpenClaw

If you have an existing OpenClaw instance (e.g., at `192.168.50.91`), Hermes can import conversations:

```bash
hermes claw migrate
```

Run this from the Hermes CLI after deployment.

## Notes

- Docker must already be installed on the target host. The `hermes.yaml` playbook runs the `docker` role first.
- First deployment builds the Docker image from source and may take several minutes.
- Re-running the playbook after a `hermes_git_version` change will trigger a rebuild automatically.
- The `hermes_data_dir` is never deleted by Ansible — memories, skills, and logs persist across role re-runs.

