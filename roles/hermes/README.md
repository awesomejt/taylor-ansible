# Hermes Role

This role bootstraps a Hermes VM with the base runtime and service user.

Current scope (iteration 1):

- Install Python 3.14
- Install uv
- Install Node.js 24 LTS
- Upgrade npm to latest
- Create hermes system user with sudo access

## Files

- `defaults/main.yaml`: Runtime and user defaults
- `tasks/main.yaml`: Host bootstrap tasks

## Variables

Key overridable variables:

- `hermes_python_version` (default: `3.14`)
- `hermes_nodejs_major_version` (default: `24`)
- `hermes_install_uv` (default: `true`)
- `hermes_user` / `hermes_group` (default: `hermes`)
- `hermes_sudo_nopasswd` (default: `true`)

## Secrets

This iteration does not require new secrets.

Future Hermes secrets should be documented in:

- `vars/common/example-secrets.yaml`
