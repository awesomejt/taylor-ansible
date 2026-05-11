# Hermes Role

This role bootstraps and deploys Hermes Agent with a Discord-enabled gateway and a web dashboard.

Current scope (profile-first with legacy compatibility):

- Install Python runtime, uv, Node.js, GitHub CLI, and base packages
- Create hermes system user with sudo access and managed git identity
- Clone and install Hermes from source into a dedicated virtual environment
- Clone AI profile repository (`ai-agents`) and install SOUL profiles
- Render Hermes config and .env from Ansible variables
- Configure Discord gateway environment settings
- Configure CIFS automount shares for Hermes content
- Install and manage systemd services:
	- `hermes-gateway-<profile>` for profiles where `gateway_enabled: true`
	- `hermes-dashboard` (web dashboard)
- Ensure enabled services are running
- Support both `hermes_profiles` (preferred) and legacy `hermes_instances` fallback

## Files

- `defaults/main.yaml`: Runtime and user defaults
- `tasks/main.yaml`: Host bootstrap + Hermes deployment tasks
- `templates/hermes-config.yaml.j2`: Main Hermes config
- `templates/hermes.env.j2`: Hermes environment variables and secrets
- `templates/hermes-gateway.service.j2`: systemd service for gateway
- `templates/hermes-dashboard.service.j2`: systemd service for dashboard
- `handlers/main.yaml`: Service restart handlers

## Variables

Key overridable variables:

- `hermes_python_version` (default: `3.14`)
- `hermes_nodejs_major_version` (default: `24`)
- `hermes_install_uv` (default: `true`)
- `hermes_user` / `hermes_group` (default: `hermes`)
- `hermes_sudo_nopasswd` (default: `true`)
- `hermes_profiles` (preferred profile-centric schema)
- `hermes_instances` (legacy fallback schema)
- `hermes_primary_profile` / `hermes_dashboard_instance` (dashboard target)
- `hermes_discord_allowed_users`
- `hermes_dashboard_host` / `hermes_dashboard_port`
- `hermes_git_user_name` / `hermes_git_user_email`
- `hermes_soul_repo` / `hermes_soul_files`
- `hermes_cifs_shares`
- `hermes_omlx_base_url` / `hermes_omlx_api_key` (legacy fallback; prefer vault secret)
- `hermes_litellm_base_url` (OpenAI-compatible LiteLLM endpoint, e.g. `http://192.168.50.91:4000/v1`)
- `hermes_searxng_url` (SearXNG base URL, e.g. `http://192.168.50.91:8081`)
- `hermes_web_backend` / `hermes_web_search_backend` / `hermes_web_extract_backend`
- `hermes_shared_auth_source_dir` (default: `/home/hermes/.hermes`, shared across profile homes)

## Secrets

Hermes secrets should be stored in:

- `vars/common/example-secrets.yaml`

Primary keys for this role:

- `vault_hermes_openrouter_api_key` (optional fallback provider key)
- `vault_hermes_omlx_api_key` (API key for OpenAI-compatible custom endpoints such as oMLX)
- `vault_openwebui_litellm_master_key` (preferred key for LiteLLM-backed Hermes profiles)
- `vault_hermes_discord_tokens` (required only for Discord-enabled gateway profiles)
