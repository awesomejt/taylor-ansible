# Hermes Role

This role bootstraps and deploys Hermes Agent with a Discord-enabled gateway and a web dashboard.

Current scope (main profile):

- Install Python runtime, uv, Node.js, and base packages
- Create hermes system user with sudo access
- Clone and install Hermes from source into a dedicated virtual environment
- Render Hermes config and .env from Ansible variables
- Configure Discord gateway environment settings
- Install and manage systemd services:
	- `hermes-gateway` (Discord/messaging gateway)
	- `hermes-dashboard` (web dashboard)
- Ensure both services are enabled at boot and running

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
- `hermes_profiles` / `hermes_active_profile` (profile-based model config)
- `hermes_discord_enabled` / `hermes_discord_allowed_users`
- `hermes_dashboard_host` / `hermes_dashboard_port`

## Secrets

Hermes secrets should be stored in:

- `vars/common/example-secrets.yaml`

Primary keys for this role:

- `vault_hermes_openrouter_api_key` (optional fallback provider key)
- `vault_hermes_discord_token` (required when Discord is enabled)
