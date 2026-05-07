# Hermes Profiles Refactor Plan

This plan migrates the Hermes role from instance-centric deployment to profile-centric deployment with a single Discord ingress profile first, while preserving future expansion to additional profile-specific bots.

## Objectives

- Reduce operational complexity by using native Hermes profiles.
- Start with one Discord ingress bot to avoid duplicate bot responses.
- Keep specialist profiles with separate SOUL, memory, sessions, and skills.
- Keep secrets in Ansible Vault on host 192.168.50.11 with backup/rollback guardrails.

## Safety Gate (must pass before refactor apply)

1. Create fresh secrets backup snapshot on host:
   - scripts/vault-secrets-backup.sh ~/ansible ~/.ansible-vault-backups 45
2. Record snapshot timestamp in change notes.
3. Perform syntax-check only before first apply:
   - ansible-playbook -i inventory.ini hermes.yaml --syntax-check --ask-vault-pass

## Target Architecture

### Profile types

- Ingress profile:
  - Gateway enabled
  - Discord enabled
  - Receives user prompts and routes work via Kanban/task assignment
- Worker profiles:
  - Gateway disabled by default
  - No Discord token required
  - Keep profile-specific SOUL and memory/state isolation

### Initial recommended mapping

- ingress: chat (or orchestrator if you prefer to separate user-facing voice from worker personas)
- workers: research, coding, admin, jessica

## Variable Schema (proposed)

Replace instance-first variables with profile-first variables.

### New role variables

- hermes_primary_profile: "chat"
- hermes_profiles:
  - name: chat
    gateway_enabled: true
    discord_enabled: true
    discord_require_mention: true
    discord_home_channel: "..."
    provider: custom
    base_url: "..."
    model: "..."
    fallback_providers: []
    soul_src: main/SOUL.md
    cli_toolsets: ["hermes-cli", "kanban-orchestrator"]
  - name: research
    gateway_enabled: false
    discord_enabled: false
    provider: custom
    base_url: "..."
    model: "..."
    fallback_providers: []
    soul_src: researcher/SOUL.md
    cli_toolsets: ["hermes-cli", "kanban-worker"]

### Secrets model

- Keep vault_hermes_openrouter_api_key, vault_hermes_omlx_api_key, vault_hermes_dashboard_password
- Keep vault_hermes_discord_tokens mapping for forward compatibility
  - only required for profiles with discord_enabled: true
- Keep vault_hermes_gh_token in Vault only

## Role/Playbook Changes

### Playbook pre-tasks

- Update Discord token assert logic:
  - validate token only for profiles where gateway_enabled=true and discord_enabled=true
  - do not assert Discord token for worker-only profiles

### Role task flow

1. Ensure base install/user/runtime tasks remain unchanged.
2. Replace per-instance include with per-profile include:
   - current: loops hermes_instances and writes ~/.hermes-<instance>
   - target: loops hermes_profiles and writes ~/.hermes/profiles/<name> (default profile can remain ~/.hermes)
3. Create profile config/.env/SOUL mappings per profile.
4. Install systemd gateway service only for profiles with gateway_enabled=true.
5. Point dashboard to hermes_primary_profile.
6. Keep profile-specific command aliases optional (or use hermes -p <name> directly).

### Templates

- Convert template context from hermes_instance to hermes_profile.
- Render DISCORD_BOT_TOKEN only when profile discord_enabled=true.
- Keep shared Discord settings where applicable.

### Security fix included in refactor

- Remove PAT-in-URL clone pattern for ai-agents repo.
- Use safer git auth pattern and no_log where secrets are templated/used.

## Migration Strategy

### Stage A: Compatibility introduction

- Add hermes_profiles support while keeping hermes_instances fallback.
- If hermes_profiles undefined, map from hermes_instances automatically.

### Stage B: Primary switch

- Set explicit hermes_profiles in vars/common/vars.yaml.
- Enable gateway only on primary ingress profile.
- Disable gateway on worker profiles.

### Stage C: Cleanup

- Remove hermes_instances-only paths after successful verification.
- Update docs/examples to profile schema.

## Verification Checklist

1. Syntax check succeeds.
2. Gateway service online for primary profile.
3. Single Discord bot responds correctly in:
   - DM
   - mention-required channels
   - free-response channels
4. Ingress profile can create/assign Kanban tasks to worker profiles.
5. Worker profiles run with distinct SOUL/memory/session state.
6. Optional: add second profile-specific bot and verify no slash command flapping (follower config as needed).

## Rollback Plan

If issues occur:

1. Stop Hermes services.
2. Restore latest known-good snapshot:
   - scripts/vault-secrets-rollback.sh <snapshot>
3. Re-run syntax check.
4. Re-apply previous known-good playbook revision.
