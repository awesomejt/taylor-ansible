# TODO

## Technitium DNS Update (2026-05-15)

- [x] Confirm latest upstream Technitium DNS version.
- [x] Repair the Technitium role upgrade/backup block.
- [x] Validate with syntax check.
- [x] Validate with ansible-lint.
- [x] Sync to Ansible host.
- [x] Run DNS playbook on Ansible host.
- [x] Confirm the backup was created before upgrade.
- [x] Commit changes locally.

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

## Docker Compose Consolidation Planning (2026-05-15)

**Goal**: Consolidate 3 separate Docker Compose hosts (Registry/50, LLDAP/51, OpenWebUI/91) into 1 unified host with Traefik virtual host routing. K8s candidates evaluated separately. Hermes and critical infrastructure services remain dedicated.

### Phase 1: Analysis & Design (CURRENT)

- [x] Audit all 16 playbooks and 14+ roles to identify services and dependencies.
- [x] Categorize services: consolidation candidates, dedicated VM requirements, K8s migration candidates.
- [x] Document dependency graph and deployment order to prevent circular bootstrap issues.
- [x] Define networking architecture (isolated stacks + shared traefik_proxy network).
- [x] Evaluate risks and mitigations (single point of failure, resource contention, port conflicts).
- [x] Document findings in MEMORY.md and TODO.md.
- [ ] **Review recommendations with user for approval before proceeding to Phase 2.**

### Phase 2: Secrets & Infrastructure Prep

- [ ] Confirm consolidated VM target IP (suggest 192.168.50.75 or reuse 192.168.50.91).
- [ ] Update inventory.ini to reflect consolidated host groups and IP.
- [ ] Plan PostgreSQL database host changes for LLDAP and OpenWebUI services:
  - [ ] LLDAP: refactor playbook to use external postgres_prod instead of embedded DB role
  - [ ] OpenWebUI: move Postgres service from compose to dedicated postgres_prod, update DATABASE_URL
- [ ] Design Traefik compose service and routing rules for web UIs:
  - [ ] Labels for automatic service discovery
  - [ ] Virtual host naming scheme (service.taylor.lan or similar)
  - [ ] TLS termination via step-ca certificates
  - [ ] Basic auth or no-auth per service
- [ ] Create example-secrets.yaml entries for new traefik passwords/TLS keys
- [ ] Plan vault secret refactoring (consolidation host address, DB hosts, Traefik auth)

### Phase 3: Playbook Refactoring

- [ ] **registry.yaml**: Update inventory target or create consolidated host target; keep role logic unchanged
- [ ] **lldap.yaml**: 
  - [ ] Remove embedded postgres provisioning from first play (now external)
  - [ ] Change lldap_db_host to external postgres_prod via secrets
  - [ ] Consolidate deploy location
- [ ] **openwebui.yaml**:
  - [ ] Remove postgres service from Docker Compose (move to separate postgres_prod deployment if not exists)
  - [ ] Change compose DATABASE_URL to external postgres_prod host
  - [ ] Consolidate deploy location
  - [ ] Ensure ollama stays on consolidated host (GPU-preferred, resource-local)
- [ ] **Create traefik.yaml** (new):
  - [ ] Traefik service on consolidated host
  - [ ] Routing to registry, lldap, openwebui, anythingllm, n8n, etc.
  - [ ] TLS cert management via step-ca role pattern
  - [ ] Dashboard UI on traefik.taylor.lan (optional)
- [ ] Create modular compose templates for consolidated host organization

### Phase 4: Validation & Testing (Local)

- [ ] Validate refactored playbooks with syntax check
- [ ] Validate with ansible-lint
- [ ] Trace dependency graph: ensure no circular bootstrap issues
- [ ] Document assumptions about external postgres_prod availability

### Phase 5: Deployment & Verification (Host)

- [ ] Sync refactored playbooks to 192.168.50.11
- [ ] Create backup snapshots of current live hosts (registry, lldap, openwebui) for rollback
- [ ] Provision consolidated Docker Compose VM (or prepare 192.168.50.91 for consolidation if reusing)
- [ ] Run baseline.yaml, docker.yaml on consolidated host
- [ ] Deploy registry, lldap, openwebui playbooks in sequence to consolidated host
- [ ] Deploy traefik.yaml to consolidated host
- [ ] Verify web services accessible via virtual hostnames (registry.taylor.lan, ldap.taylor.lan, etc.) through Traefik
- [ ] Verify LDAP protocol still works on direct port 3890
- [ ] Update DNS records if hostname structure changed
- [ ] Verify external postgres_prod connections from services
- [ ] Decommission old hosts (192.168.50.50, 192.168.50.51) after verification window

### Phase 6: K8s Migration Planning (Separate)

- [ ] Evaluate which services benefit from K8s StatefulSet + horizontal scaling:
  - [ ] Nexus Repository OSS → StatefulSet with persistent volume
  - [ ] Registry → StatefulSet (though light enough for Docker Compose)
  - [ ] LiteLLM gateway → Deployment (stateless gateway, scales well)
  - [ ] OpenWebUI → Deployment (stateless UI, scales well)
  - [ ] AnythingLLM → StatefulSet (may have local document storage)
  - [ ] N8N → StatefulSet (workflow state/DB needed)
  - [ ] SearXNG → Deployment (stateless search proxy)
  - [ ] Qdrant → StatefulSet (vector DB, persistence required)
- [ ] Create GitOps-driven K8s manifests or Helm charts for K8s-bound services
- [ ] Assess impact on docker.yaml and consolidated Docker Compose host if services are moved
- [ ] Plan gradual migration: keep docker-compose versions available until K8s validation complete

### Open Questions & Decisions Pending User Review

- [ ] **Consolidated host IP**: Use 192.168.50.91 (current OpenWebUI host) or new IP 192.168.50.75?
- [ ] **Traefik ingress**: Host on consolidated Docker Compose or in K3s?
- [ ] **LLDAP persistence**: Stay Docker Compose or consider K8s migration?
- [ ] **Ollama**: Stay on consolidated Docker Compose (GPU affinity, local storage) or move to K8s?
- [ ] **Registry backups**: Backup strategy for consolidated host (snapshots, off-host replication)?
- [ ] **External database approach**: Keep postgres_prod centralized or distribute per-environment DB VMs?
- [ ] **Timeline**: Consolidate immediately or pilot with one service first (e.g., registry)?

### Risks & Mitigations (see MEMORY.md for details)

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Single host failure | LLDAP + Registry + OpenWebUI down | Snapshots, fast failover to K8s for stateless services, HA backup host |
| Resource contention | CPU/memory bottleneck | Right-size VM (16GB RAM, 8+ cores), monitor, split into 2 hosts if needed |
| Port conflicts | Service unavailable | Use Traefik on :80/:443, non-standard internal ports (8000+) |
| Dependency ordering | Playbook hangs/fails | Validate postgres_prod exists before LLDAP/OpenWebUI, test bootstrap from scratch |

## Docker Compose Consolidation - Research & Refinement Tasks (2026-05-15)

### Research Item 1: Docker Registry & Asset Management Strategy

**Goal**: Evaluate Docker registry options (simple registry vs Harbor vs Nexus) and determine best approach for build asset/library management.

- [ ] Research current simple Docker registry (192.168.50.50):
  - [ ] Document current capabilities, limitations (no UI, no auth, no vulnerability scanning)
  - [ ] Document resource footprint (CPU, memory, disk)
  - [ ] Note external UI solution currently in use (Nginx proxy)
  - [ ] Assess suitability for current needs

- [ ] Research Harbor as alternative:
  - [ ] Document feature set (UI, RBAC, vulnerability scanning, replication, retention policies)
  - [ ] Compare resource requirements vs simple registry
  - [ ] Learning curve and operational complexity
  - [ ] Deployment options (Docker Compose vs Kubernetes)
  - [ ] Migration path from simple registry

- [ ] Research Nexus as all-in-one solution:
  - [ ] Current state: 192.168.50.12, systemd binary deployment
  - [ ] Document resource footprint (~2GB+?)
  - [ ] Feature set beyond Docker (Maven, npm, PyPI, raw storage, etc.)
  - [ ] Learning curve
  - [ ] Assess if overkill for current needs or justifiable consolidation

- [ ] Define library/dependency management needs:
  - [ ] Which package types currently needed? (Docker images, npm, Maven, PyPI, Go modules, etc.)
  - [ ] Future package types anticipated?
  - [ ] HA/redundancy requirements?
  - [ ] Data retention policies?

- [ ] Document recommendation:
  - [ ] Option A: Keep simple registry as-is (lightweight, limited scope)
  - [ ] Option B: Migrate to Harbor (comprehensive but moderate overhead)
  - [ ] Option C: Consolidate library mgmt into Nexus (single source of truth, higher overhead)
  - [ ] Option D: Keep registry separate from libraries (dual-service approach)
  - [ ] Include: pros/cons, resource profile, deployment effort, migration path

### Research Item 2: Nexus Placement & Consolidation Decision

**Goal**: Determine whether Nexus should remain dedicated VM (192.168.50.12) or fold into consolidated Docker Compose host.

- [ ] Analyze current Nexus deployment:
  - [ ] Current state: systemd binary, Java runtime, ~2GB footprint
  - [ ] Resource utilization: CPU, memory, disk I/O
  - [ ] Current storage/persistence approach

- [ ] Evaluate consolidation options:
  - [ ] Option A: Convert to Docker Compose, deploy on consolidated host
  - [ ] Option B: Keep dedicated VM but switch to Docker Compose (easier than binary)
  - [ ] Option C: Migrate to K8s StatefulSet (for HA if needed later)
  - [ ] Option D: Leave as-is on dedicated VM

- [ ] Decision criteria:
  - [ ] Resource availability on consolidated host (if consolidating)
  - [ ] Isolation benefits vs resource efficiency tradeoff
  - [ ] Backup/restore complexity on consolidated vs dedicated
  - [ ] Artifact replication needs (local only vs multi-site)
  - [ ] HA requirements (user confirmed: none for now)

- [ ] Document recommendation with decision matrix

### Research Item 3: AI Compose Stack Decomposition Architecture

**Goal**: Design decomposed AI stack with separate Traefik-routed services instead of monolithic compose.

- [ ] Current state documentation:
  - [ ] List current services in AI stack (open-webui, litellm, ollama, searxng, anythingllm, n8n, qdrant, postgres)
  - [ ] Document service interdependencies
  - [ ] Document current network/port layout
  - [ ] Document current environment variables and secrets

- [ ] Design decomposed structure:
  - [ ] One Docker Compose file per service (or logical grouping)
  - [ ] Define Traefik virtual hostnames:
    - [ ] openwebui.taylor.lan → open-webui service
    - [ ] litellm.taylor.lan (or litellm-gateway.taylor.lan) → litellm service
    - [ ] searxng.taylor.lan → searxng service
    - [ ] anythingllm.taylor.lan → anythingllm service
    - [ ] n8n.taylor.lan → n8n service
    - [ ] qdrant.taylor.lan (or qdrant-api.taylor.lan) → qdrant service
  - [ ] Define traefik_proxy network connections for each
  - [ ] Define internal service-to-service networking (if needed)
  - [ ] Document port mappings and Traefik routing rules

- [ ] Plan Ollama separation:
  - [ ] Move ollama to dedicated VM (CPU-only fallback provider)
  - [ ] Document Ollama API endpoint in vault (for LiteLLM to discover)
  - [ ] Ensure LiteLLM can route to external ollama endpoint
  - [ ] Plan model pulling/syncing strategy for Ollama VM

- [ ] Define service interdependencies after decomposition:
  - [ ] LiteLLM needs Qdrant? Ollama? Database?
  - [ ] OpenWebUI needs LiteLLM? Ollama?
  - [ ] AnythingLLM needs what?
  - [ ] N8N needs what?
  - [ ] Map out startup order to avoid race conditions

- [ ] Document refactoring approach for playbook/roles:
  - [ ] Current: openwebui.yaml deploys 8-service monolith
  - [ ] Proposed: openwebui.yaml orchestrates multiple compose files or calls separate playbooks
  - [ ] Consider: single playbook per service vs orchestrating playbook
  - [ ] Versioning/rollback strategy for decomposed services

### Research Item 4: Common Homelab Services Recommendations

**Goal**: Research and recommend commonly-run services suitable for consolidated Docker Compose host.

- [ ] Monitoring & Logging Stack:
  - [ ] Prometheus + Grafana (metrics + dashboards)
  - [ ] Loki (log aggregation, lightweight alternative to ELK)
  - [ ] Alertmanager (alert routing)
  - [ ] cAdvisor or node-exporter (system/container metrics)
  - [ ] Resource requirements and Traefik integration

- [ ] Access Control & Auth:
  - [ ] Authelia (SSO, OIDC, multi-factor)
  - [ ] Nginx auth_request module setup
  - [ ] Integration with LLDAP (already deployed)
  - [ ] Alternative: Keycloak (heavier)

- [ ] Database Tools:
  - [ ] pgAdmin (PostgreSQL UI for easy DB inspection)
  - [ ] DBeaver or Adminer (lightweight DB clients)
  - [ ] Placement on consolidated host or separate

- [ ] Media & File Sharing:
  - [ ] Jellyfin (media server alternative to Plex)
  - [ ] Nextcloud (file sync + collaboration)
  - [ ] Syncthing (distributed file sync)
  - [ ] Resource requirements (Jellyfin can be heavy with transcoding)

- [ ] Home Automation:
  - [ ] Home Assistant (IoT/smart home orchestration)
  - [ ] MQTT broker (Mosquitto, lightweight pub/sub)
  - [ ] Node-RED (visual automation workflows)
  - [ ] Typical resource usage and persistence needs

- [ ] VPN & Networking:
  - [ ] Wireguard (VPN protocol, lightweight)
  - [ ] Tailscale (managed VPN, simplicity)
  - [ ] Placement considerations (usually on edge host)

- [ ] Development & Git:
  - [ ] Gitea or Forgejo (lightweight Git server)
  - [ ] Woodpecker CI (lightweight CI/CD)
  - [ ] Resource requirements and persistence

- [ ] Document final recommendations:
  - [ ] Top 3-5 services best suited for consolidated Docker Compose host
  - [ ] Include resource profiles (CPU, memory, disk I/O)
  - [ ] Traefik integration notes for each
  - [ ] Dependency on existing services (e.g., Authelia + LLDAP)
  - [ ] Suggested stack ordering (what to deploy when)
  - [ ] Note: user can pick and choose based on needs

### Research Item 5: Consolidated Host IP & Naming Finalization

**Goal**: Finalize consolidated Docker Compose host IP and update inventory/DNS accordingly.

- [ ] Decide consolidated host IP:
  - [ ] Option A: Reuse 192.168.50.91 (current OpenWebUI host, consolidate all there)
  - [ ] Option B: New IP 192.168.50.75 (or other available)
  - [ ] Criteria: proximity to existing services, IP pool availability
  - [ ] **Decision**: [awaiting user choice]

- [ ] Update inventory.ini with new consolidated host group:
  - [ ] `[docker_compose_consolidated]` or similar group name
  - [ ] Remove/reassign old groups (registry, openwebui, lldap)
  - [ ] Map decommissioned IPs (192.168.50.50, 192.168.50.51, possibly 192.168.50.91)

- [ ] Update DNS records (Technitium on 192.168.50.53):
  - [ ] registry.taylor.lan → consolidated IP
  - [ ] ldap.taylor.lan → consolidated IP
  - [ ] openwebui.taylor.lan → consolidated IP
  - [ ] litellm.taylor.lan → consolidated IP
  - [ ] searxng.taylor.lan → consolidated IP
  - [ ] anythingllm.taylor.lan → consolidated IP
  - [ ] n8n.taylor.lan → consolidated IP
  - [ ] qdrant.taylor.lan → consolidated IP
  - [ ] Any new services → consolidated IP

- [ ] Plan decommissioning:
  - [ ] When does 192.168.50.50 (registry VM) get retired?
  - [ ] When does 192.168.50.51 (LLDAP VM) get retired?
  - [ ] When does 192.168.50.91 (OpenWebUI VM) get retired (if reusing for consolidated)?
  - [ ] Backup/snapshot strategy before decommissioning
