# TODO

## LLDAP Role + Playbook (2026-05-15)

- [x] Review existing role and playbook scaffolding.
- [x] Fix compose dependency ordering for lldap/nginx services.
- [x] Ensure playbook provisions PostgreSQL database/user on `postgres_prod`.
- [x] Add sanitized LLDAP secret placeholders in `vars/common/example-secrets.yaml`.
- [x] Add LLDAP secrets to vaulted `vars/common/secrets.yaml` on 192.168.50.11.
- [x] Validate with syntax check.
- [x] Validate with ansible-lint.
- [x] Sync to Ansible host.
- [x] Run playbook on Ansible host.
- [x] Verify UI and LDAP endpoints by IP (`http://192.168.50.51`, `ldap://192.168.50.51:3890`).
- [x] Verify DNS-based endpoint from Ansible host (`ldap.taylor.lan`) after DNS record propagation/fix.

## HashiCorp Vault Role + Playbook (2026-05-14)

- [x] Design role structure (native binary + Raft storage + Nginx proxy).
- [x] Create `vault.yaml` playbook.
- [x] Implement `roles/vault` with systemd service and Nginx reverse proxy.
- [x] Add vault host (192.168.50.13) to inventory.ini.
- [x] Create role README with init/unseal steps and step-ca TLS guidance.
- [x] Validate with syntax check.
- [ ] Sync to Ansible host.
- [ ] Run playbook on Ansible host.
- [ ] Initialize and unseal Vault manually on 192.168.50.13.
- [ ] (Optional) Enable TLS via step-ca cert — see role README.

## Docker Registry Role + Playbook (2026-05-14)

- [x] Review current Docker Registry v3 deployment guidance.
- [x] Create `registry.yaml` playbook using updates/common/docker as the foundation.
- [x] Implement `roles/registry` with Docker Compose deployment for `registry:3`.
- [x] Add Nginx reverse proxy in front of the registry with TLS-ready configuration.
- [x] Validate with syntax check.
- [x] Validate with ansible-lint.
- [x] Sync to Ansible host.
- [x] Run playbook on Ansible host.
- [x] Verify registry endpoint (`/v2/`) behavior from host/network.

## Step CA Automation And Rollout (2026-05-13)

- [x] Review current step-ca playbook and role state.
- [x] Enable automated non-interactive init in playbook defaults.
- [x] Add/refresh role documentation for apply workflow and manual steps.
- [x] Update main README with step-ca usage reference.
- [x] Validate with syntax check.
- [x] Sync to Ansible host.
- [x] Ensure required step-ca secrets exist in vaulted vars/common/secrets.yaml.
- [x] Run playbook on Ansible host.
- [x] Verify step-ca service and CA health on 192.168.50.9.

## Hermes LiteLLM + SearXNG Migration (2026-05-10)

- [x] Switch Hermes profile model routing to LiteLLM endpoint aliases.
- [x] Configure Hermes web backend to use SearXNG search.
- [x] Add SearXNG URL and LiteLLM key wiring in Hermes env template.
- [x] Validate with syntax check.
- [x] Sync to Ansible host.
- [x] Run playbook on Ansible host.
- [x] Verify Hermes gateway/dashboard healthy after restart.

## LiteLLM Dashboard DB Auth Fix (2026-05-10)

- [x] Confirm runtime root cause from logs (`Not connected to DB`).
- [x] Add Postgres service and LiteLLM `DATABASE_URL` wiring in AI stack compose template.
- [x] Add secrets-backed Postgres password variable for AI stack.
- [x] Add sanitized secret placeholder entry in example-secrets.
- [x] Validate with syntax check.
- [x] Sync to Ansible host.
- [x] Run playbook on Ansible host.
- [x] Verify LiteLLM auth endpoints no longer return DB-not-connected.

## Hermes Migration Plan

### Goals
- Move Hermes deployment from custom multi-instance orchestration to Hermes profiles where that simplifies coordination.
- Start with a single Discord bot/profile for ingress if it supports delegation and future expansion cleanly.
- Preserve the option to add profile-specific bots later for specialized use cases.
- Keep secrets in Ansible Vault on the host for now, with simple rollback-friendly backups.

### Working Constraints
- Do not make direct secret edits in this local repo.
- Apply real changes on the Ansible host `192.168.50.11` in `~/ansible`.
- Local Ansible commands are allowed for syntax/lint validation only.
- Local `example-secrets.yaml` files must contain placeholders only.

### Decisions Confirmed
- Prefer a single Discord bot first to avoid multi-bot overlap and duplicate responses.
- Use Hermes profiles as the default multi-agent model when possible.
- Use Kanban/profile assignment for delegation between specialist profiles.
- Keep future support for additional profile-specific bots when a direct user-facing bot is actually needed.
- Keep secrets in Ansible Vault for now instead of introducing a full secrets manager.
- Add backup/rollback coverage for vaulted secret files on the host.

## Execution Plan

### Phase 1: Design
- [ ] Finalize target Hermes architecture: one Discord ingress profile plus worker profiles.
- [ ] Define which profiles need direct gateway access versus Kanban-only worker behavior.
- [ ] Decide naming/layout for Hermes profiles, profile homes, and SOUL source mapping from `ai-agents`.
- [ ] Define secrets model for profile env generation and future optional per-profile bot tokens.

### Phase 2: Ansible Refactor Plan
- [x] Draft profile-centric refactor plan in HERMES_PROFILES_REFACTOR_PLAN.md.
- [x] Stage A: add profile-aware compatibility layer with legacy fallback (`hermes_profiles_effective`).
- [x] Stage A: support gateway-enabled vs worker-only profiles (`gateway_enabled`).
- [x] Stage A: remove hard requirement that every profile has a Discord token.
- [x] Stage A: update dashboard targeting to primary profile (`hermes_primary_profile` fallback).
- [ ] Stage B: move profile homes/services from legacy naming to native profile layout.
- [x] Stage B: define explicit `hermes_profiles` in vars/common/vars.yaml for ingress + workers.
- [ ] Stage C: fix AI-agents clone auth handling so tokens are not embedded in repo URLs.
- [ ] Stage C: remove remaining `hermes_instances`-only paths after verification.

### Phase 3: Secrets and Backups
- [ ] Keep real secrets only in vaulted files on `192.168.50.11:~/ansible`.
- [x] Ensure local `vars/common/example-secrets.yaml` stays placeholder-only.
- [x] Design a simple cron-based backup of vaulted secrets on the host.
- [x] Define rollback procedure for restoring previous vaulted secrets if a bad update breaks Hermes.

### Phase 4: Validation and Rollout
- [ ] Validate updated playbook/role syntax locally.
- [ ] Apply changes on `192.168.50.11` from `~/ansible`.
- [ ] Verify single Discord bot behavior in DM, mention, and free-response channels.
- [ ] Verify the ingress profile can create/assign Kanban tasks to worker profiles.
- [ ] Verify worker profiles retain separate SOUL, memory, and session state.
- [ ] Verify future addition of a second profile-specific bot remains possible without reworking the core model.

## Open Questions
- [ ] Which profile should be the initial Discord ingress profile: `chat`, `admin`, or a new `orchestrator` profile?
- [ ] Which current profiles should remain directly user-facing versus becoming worker-only?
- [ ] Should Discord slash command registration be owned only by the primary bot profile from day one?
- [ ] What retention schedule and destination should secrets backups use on the host?

## Current Status
- [x] Confirm Hermes official docs support profiles with separate SOUL/memory/state.
- [x] Confirm Hermes Kanban is designed for cross-profile collaboration.
- [x] Confirm one bot token is tied to one running gateway/profile.
- [x] Confirm a single-bot-first approach matches the current preference.
- [x] Draft the concrete Ansible refactor design.
- [x] Implement Stage A role/playbook compatibility changes.
- [ ] Implement Stage B profile-home layout and vars migration.
- [ ] Validate and roll out on the host.
