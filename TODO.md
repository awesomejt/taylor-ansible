# TODO

## Kanban (Vikunja) Rollout (2026-05-16)

- [x] Create `kanban.yaml` playbook using `vikunja` role.
- [x] Add `roles/vikunja` with compose/systemd deployment and readiness checks.
- [x] Wire Traefik hostname to `kanban.taylor.lan`.
- [x] Add inventory target group `kanban`.
- [x] Add sanitized `vault_vikunja_service_secret` placeholder to `vars/common/example-secrets.yaml`.
- [x] Switch Vikunja backend to common/prod PostgreSQL (`192.168.50.15`) with DB provisioning in `kanban.yaml`.
- [x] Enable Vikunja LDAP authentication against LLDAP (`ldap.taylor.lan:3890`) for central auth.
- [x] Validate playbook locally (`ansible-playbook --syntax-check`, `ansible-lint`).
- [x] Sync to Ansible host.
- [x] Run `kanban.yaml` on Ansible host.
- [x] Verify routed endpoint (`kanban.taylor.lan`) responds.
- [x] Set `vault_vikunja_service_secret` and `vault_vikunja_db_password` in vaulted `vars/common/secrets.yaml` on 192.168.50.11 and re-apply `kanban.yaml`.

## Compose Ops Services Rollout (2026-05-16)

- [x] Add decomposed roles and playbooks for Prometheus, Grafana, pgAdmin, and Portainer.
- [x] Add inventory groups for new services on the consolidated host.
- [x] Add sanitized secret placeholders in `vars/common/example-secrets.yaml`.
- [x] Validate playbooks locally (`ansible-playbook --syntax-check`, `ansible-lint`).
- [x] Sync to Ansible host.
- [x] Apply playbooks on Ansible host.
- [x] Verify routes respond through Traefik.

## AI Stack Validation Automation (2026-05-16)

- [x] Create validation script template for routed AI stack health checks.
- [x] Add role to deploy script, env file, cron schedule, and log file.
- [x] Configure hourly cron schedule.
- [x] Configure logrotate policy for validation logs.
- [x] Validate playbook syntax and ansible-lint locally.
- [x] Sync to Ansible host.
- [x] Run playbook on Ansible host.
- [x] Verify cron/logrotate installation and run validation once manually.

## Cleanup + Archiving Hygiene (2026-05-16)

- [x] Remove deprecated LDAP compatibility playbook (`lldap.yaml`) and keep `ldap.yaml` as sole entrypoint.
- [x] Remove unused legacy LLDAP nginx template (`roles/lldap/templates/nginx.conf.j2`).
- [x] Update role/docs memory references for ldap-only naming.
- [x] Define soft/hard archive workflow in `archive/README.md`.
- [x] Mark OpenClaw as dormant and document reactivation runbook in `archive/openclaw.md`.
- [x] Hard-archive OpenClaw by moving playbook/role into `archive/` paths and removing active top-level README run instructions.

## LDAP Auth Expansion Review (2026-05-16)

- [x] Review currently deployed services for LDAP-capable authentication flows.
- [x] Confirm Vikunja LDAP remains enabled against LLDAP.
- [x] Add Grafana LDAP auth wiring to role defaults/templates/tasks.
- [x] Add pgAdmin LDAP auth wiring to role defaults/templates/tasks.
- [x] Evaluate whether Open WebUI (chat.taylor.lan) can use LDAP authentication via LLDAP and wire it if supported.
- [x] Validate LDAP-related playbook changes with syntax check.
- [x] Validate LDAP-related playbook changes with ansible-lint.

## AI Services LDAP/LLDAP Compatibility Follow-Up (2026-05-16)

- [x] Confirm Open WebUI LDAP support for the deployed image tag and wire role vars/templates if native LDAP is available in this version.
- [x] Evaluate AnythingLLM auth options (native LDAP vs SSO) and document whether LLDAP is directly supported or requires an external IdP bridge (no confirmed free native LDAP path in current docs).
- [x] Evaluate n8n LDAP capability for the deployed edition and wire LLDAP settings if available (skipped: docs mark LDAP as Self-hosted Business/Enterprise feature).
- [x] Evaluate LiteLLM Admin UI SSO integration and document an LLDAP-compatible path (for example, LLDAP via OIDC broker) when direct LDAP is not supported (skipped for now: not a direct free LDAP path in current stack).
- [x] Decide access-control approach for AI services that do not expose native LDAP auth (SearXNG, Qdrant, Ollama): keep network-only exposure behind Traefik/internal network unless a free auth proxy is added.
- [x] Apply any newly LDAP/SSO-wired AI service playbooks on the Ansible host after local validation.

## Open WebUI Web Search Fix (2026-05-16)

- [x] Confirm Open WebUI image expects `ENABLE_WEB_SEARCH` / `WEB_SEARCH_ENGINE` keys.
- [x] Update Open WebUI compose template to set current web-search keys (and keep legacy keys for compatibility).
- [x] Validate locally (`ansible-playbook --syntax-check`, `ansible-lint`).
- [x] Sync to Ansible host.
- [x] Re-apply `openwebui.yaml` on Ansible host.
- [x] Verify runtime env and SearXNG connectivity from Open WebUI container.

## LiteLLM + Open WebUI Provider Audit (2026-05-16)

- [x] Verify live oMLX model inventories on primary (`192.168.50.93`) and secondary (`192.168.50.94`) with vault API key.
- [x] Verify live Ollama model inventory on fallback host (`192.168.50.51`).
- [x] Update LiteLLM Ollama defaults to currently available models.
- [x] Fix LiteLLM legacy `local-ollama` alias so configured fallbacks target a defined model.
- [x] Add direct provider aliases in LiteLLM for newly available Ollama and oMLX models.
- [x] Configure Open WebUI to keep LiteLLM as default while exposing direct oMLX OpenAI-compatible endpoints for testing.
- [x] Validate locally (`ansible-playbook --syntax-check`, `ansible-lint`).
- [x] Sync to Ansible host.
- [x] Run `litellm.yaml` and `openwebui.yaml` on Ansible host.
- [x] Verify runtime behavior (routes, LiteLLM models list, and sample completions).

## AI Stack Rollout - Decomposed Roles (2026-05-16)

- [x] Validate updated playbooks locally (`ansible-playbook --syntax-check`)
- [x] Validate updated playbooks locally (`ansible-lint`)
- [x] Sync repository to Ansible host via `./sync-to-ansible.sh`
- [x] Ensure AI stack secrets exist in Ansible Vault on 192.168.50.11 (`vars/common/secrets.yaml`)
- [x] Apply playbooks on Ansible host in order (`traefik`, `qdrant`, `searxng`, `litellm`, `anythingllm`, `n8n`, `openwebui`)
- [x] Validate server-side deployment on 192.168.50.50 (systemd, docker containers, routed endpoint checks)
- [x] Fix readiness probes for Traefik-routed services and re-apply affected playbooks
- [x] Fix runtime startup issues: LiteLLM Postgres auth, N8N data-dir permissions, AnythingLLM storage configuration/permissions
- [x] Perform manual browser validation of each UI and core flows (confirmed: n8n, AnythingLLM, Open WebUI, SearXNG)

## Ollama Reverse Proxy For Web Access (2026-05-15)

- [x] Add optional Nginx reverse proxy support in `roles/ollama`.
- [x] Keep direct Ollama API access on port `11434` for LiteLLM and other clients.
- [x] Wire common vars for hostname-based browser access.
- [x] Validate with syntax check.
- [x] Validate with ansible-lint.
- [ ] Sync to Ansible host.
- [ ] Run playbook on Ansible host.
- [x] Commit changes locally.

## Ollama Containerized Nginx Sidecar (2026-05-15)

- [x] Refactor reverse proxy from host-level nginx to Compose sidecar.
- [x] Keep direct Ollama API access on port `11434` unchanged.
- [x] Keep reverse proxy configurable through role defaults/common vars.
- [x] Validate with syntax check.
- [x] Validate with ansible-lint.
- [ ] Sync to Ansible host.
- [ ] Run playbook on Ansible host.
- [x] Commit changes locally.

## Technitium DNS Update (2026-05-15)

- [x] Confirm latest upstream Technitium DNS version.
- [x] Repair the Technitium role upgrade/backup block.
- [x] Validate with syntax check.
- [x] Validate with ansible-lint.
- [x] Sync to Ansible host.
- [x] Run DNS playbook on Ansible host.
- [x] Confirm the backup was created before upgrade.
- [x] Commit changes locally.

## LLDAP Role + Playbook (2026-05-15/16)

- [x] Review existing role and playbook scaffolding.
- [x] Migrate LLDAP web routing from nginx sidecar to Traefik labels/network.
- [x] Ensure playbook provisions PostgreSQL database/user on `postgres_prod`.
- [x] Add canonical LDAP playbook name `ldap.yaml` and retire legacy `lldap.yaml` compatibility playbook.
- [x] Add sanitized LLDAP secret placeholders in `vars/common/example-secrets.yaml`.
- [x] Add LLDAP secrets to vaulted `vars/common/secrets.yaml` on 192.168.50.11.
- [x] Validate with syntax check.
- [x] Validate with ansible-lint.
- [x] Sync to Ansible host.
- [x] Run playbook on Ansible host (`ldap.yaml`).
- [x] Verify UI and LDAP endpoints by IP (`http://192.168.50.50`, `ldap://192.168.50.50:3890`).
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

### Phase 1: Analysis & Design (COMPLETE)

- [x] Audit all 16 playbooks and 14+ roles to identify services and dependencies.
- [x] Categorize services: consolidation candidates, dedicated VM requirements, K8s migration candidates.
- [x] Document dependency graph and deployment order to prevent circular bootstrap issues.
- [x] Define networking architecture (isolated stacks + shared traefik_proxy network).
- [x] Evaluate risks and mitigations (single point of failure, resource contention, port conflicts).
- [x] Document findings in MEMORY.md and TODO.md.
- [x] Review recommendations with user for approval before proceeding to Phase 2.

### Phase 2: Secrets & Infrastructure Prep

- [x] Confirm consolidated VM target IP: `192.168.50.50` for Docker Compose stacks.
- [x] Confirm dedicated Ollama host IP: `192.168.50.51`.
- [x] Define recommended VM specs for Compose and Ollama hosts (documented in MEMORY.md).
- [x] Reinitialize VMs for new roles before implementation (user-managed prerequisite, complete as of 2026-05-15).
- [x] Apply VM sizing at reinit:
  - [x] Compose host (`192.168.50.50`): 8 vCPU, 32 GB RAM, 80-100 GB OS disk, 1.0-1.5 TB data SSD/NVMe
  - [x] Ollama host (`192.168.50.51`): 16 vCPU, 64 GB RAM, 80-100 GB OS disk, 500 GB-1 TB model NVMe
- [x] Place Compose and Ollama on different Proxmox nodes to balance memory/disk pressure.
- [x] Validate post-reinit host capacity baseline (CPU steal, RAM headroom, disk IOPS/latency).
- [x] Run Proxmox node fit analysis before VM reinit:
  - [x] Capture each node capacity (total/free vCPU threads, RAM, local SSD/NVMe free space, IOPS class)
  - [x] Assign Ollama VM (`192.168.50.51`) to compute-strong node with best RAM headroom and NVMe throughput
  - [x] Assign Compose VM (`192.168.50.50`) to storage-strong node with best sustained disk capacity
  - [x] Confirm post-placement node headroom target (>=20-25% RAM free, acceptable CPU contention)
  - [x] Document node-to-VM mapping decision in MEMORY.md
  - [x] Recommended mapping from current snapshot: `192.168.50.50` -> `homelab`, `192.168.50.51` -> `homelab2`
  - [x] Revised Ollama fallback sizing target: start at 12 vCPU / 32 GiB RAM, scale to 16 vCPU / 48 GiB if needed
- [x] Update inventory.ini to reflect consolidated host groups and IP.
- [x] Plan PostgreSQL database host changes for LLDAP and OpenWebUI services:
  - [x] LLDAP: refactor playbook to use external postgres_prod instead of embedded DB role
  - [x] OpenWebUI: move Postgres service from compose to dedicated postgres_prod, update DATABASE_URL
- [ ] Design Traefik compose service and routing rules for web UIs:
  - [ ] Labels for automatic service discovery
  - [ ] Virtual host naming scheme (service.taylor.lan or similar)
  - [ ] TLS termination via step-ca certificates
  - [ ] Basic auth or no-auth per service
- [ ] Create example-secrets.yaml entries for new traefik passwords/TLS keys
- [ ] Plan vault secret refactoring (consolidation host address, DB hosts, Traefik auth)

**Note:** DNS CNAME records have been added to alias multiple service hostnames to `docker.taylor.lan` (192.168.50.50) for simplified access and migration flexibility.

## Ollama Deployment (2026-05-15)

**Purpose**: Deploy Ollama LLM inference server on dedicated host (192.168.50.51) before OpenWebUI stack consolidation. Provides CPU-only fallback inference and embedding model support for LiteLLM and AnythingLLM.

- [ ] Validate ollama.yaml syntax check locally
- [ ] Sync to Ansible host
- [ ] Run ollama.yaml playbook on Ansible host
- [ ] Verify Ollama service is ready on http://192.168.50.51:11434
- [ ] (Optional) Pull initial models for inference or embedding (e.g., llama3.2, qwen2.5-coder, ministral-3)
- [ ] Commit changes locally

### Phase 3: Playbook Refactoring

- [x] **registry.yaml**: Update inventory target or create consolidated host target; keep role logic unchanged
- [x] **ldap/lldap playbooks**:
  - [x] Remove embedded postgres provisioning from the prior LLDAP-only deployment model
  - [x] Change lldap DB backend to external `postgres_prod`
  - [x] Consolidate deploy location on `192.168.50.50`
- [x] **openwebui.yaml**:
  - [x] Remove postgres service from Docker Compose (external postgres_prod)
  - [x] Change compose DATABASE_URL to external postgres_prod host
  - [x] Consolidate deploy location
  - [x] Ensure LiteLLM points to external Ollama endpoint on `192.168.50.51`
- [x] **Create traefik.yaml** (new):
  - [x] Traefik service on consolidated host
  - [x] Routing to registry, ldap/lldap, openwebui, anythingllm, n8n, etc.
  - [ ] TLS cert management via step-ca role pattern
  - [x] Dashboard UI on traefik.taylor.lan
- [x] Create modular compose templates for consolidated host organization

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

- [x] **Consolidated host IP**: `192.168.50.50`.
- [x] **Traefik ingress**: Dual model confirmed — Traefik on Compose host for Compose stacks + built-in Traefik in each K3s cluster for cluster workloads.
- [ ] **LLDAP persistence**: Stay Docker Compose or consider K8s migration?
- [x] **Ollama placement**: Dedicated VM at `192.168.50.51` (CPU fallback provider).
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

**User priority constraints (locked):**
- [x] Simple but reliable
- [x] Web UI required (proxied via Traefik)
- [x] Can run unsecured initially before TLS setup
- [x] Docker images are primary focus
- [x] Maven/Gradle and potential npm support desirable (not required to be same tool)
- [x] Upstream proxy support is nice-to-have
- [x] Free/open source only
- [x] Datastore should be included or support PostgreSQL in free model

**Recommended phased approach (planning decision):**
- [x] Phase A: Docker-first approach on Compose host, keep architecture simple
- [x] Phase B: Add broader dependency/package tooling only when Maven/npm demand is real
- [ ] Final Day-1 tool decision: Harbor vs Docker Distribution + lightweight UI
- [ ] Day-2 expansion decision: if/when to introduce Nexus OSS for Maven/npm ecosystems

**Priority-fit scoring (working recommendation):**
- [x] Harbor is currently best overall fit for priority mix (Docker-first + built-in UI + OSS + proxy-cache capability + included DB components).
- [x] Docker Distribution + lightweight UI is best low-complexity fallback if Harbor operational footprint is too high.
- [x] Nexus OSS is treated as Day-2 package expansion candidate, not Day-1 Docker-first default.

**Decision gates before implementation:**
- [ ] Gate 1: Choose Day-1 artifact path:
  - [ ] Option A (recommended): Harbor on `192.168.50.50`, Traefik-routed, HTTP first then TLS
  - [ ] Option B: Docker Distribution + UI on `192.168.50.50`, Traefik-routed, HTTP first then TLS
- [ ] Gate 2: Confirm repository scope at Day-1:
  - [ ] Docker hosted repo (required)
  - [ ] Docker proxy cache (optional but recommended)
  - [ ] Maven/npm proxies (defer unless immediate need)
- [ ] Gate 3: Confirm security rollout sequence:
  - [ ] Initial lab mode (unsecured internal HTTP)
  - [ ] Step-CA/TLS enablement via Traefik
  - [ ] Optional auth hardening after TLS baseline

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

**Planning decision for Harbor Day-1 path:**
- [x] If Harbor is selected for Docker registry, Nexus stays on a dedicated VM (prefer `192.168.50.12`), not on consolidated Compose host.
- [x] Preferred Nexus runtime model: Docker Compose on dedicated VM (not direct systemd binary).
- [x] Introduce Nexus only when Maven/Gradle/npm demand is recurring and material.
- [x] User approved this placement recommendation for future Day-2 use.

- [ ] Analyze current Nexus deployment:
  - [ ] Current state: systemd binary, Java runtime, ~2GB footprint
  - [ ] Resource utilization: CPU, memory, disk I/O
  - [ ] Current storage/persistence approach

- [ ] Evaluate consolidation options:
  - [ ] Option A: Convert to Docker Compose, deploy on consolidated host
  - [x] Option B: Keep dedicated VM but switch to Docker Compose (easier than binary)
  - [ ] Option C: Migrate to K8s StatefulSet (for HA if needed later)
  - [ ] Option D: Leave as-is on dedicated VM

- [ ] Decision criteria:
  - [ ] Resource availability on consolidated host (if consolidating)
  - [ ] Isolation benefits vs resource efficiency tradeoff
  - [ ] Backup/restore complexity on consolidated vs dedicated
  - [ ] Artifact replication needs (local only vs multi-site)
  - [ ] HA requirements (user confirmed: none for now)

- [ ] Document recommendation with decision matrix
- [ ] Plan Day-2 Nexus rollout (only if demand trigger is met):
  - [ ] Define demand trigger threshold (team/project count or package volume)
  - [ ] Reserve dedicated VM capacity for Nexus (CPU/RAM/disk)
  - [ ] Define Traefik route and hostname for Nexus UI/API
  - [ ] Define backup/restore cadence for Nexus data volume

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
    - [ ] chat.taylor.lan → open-webui service
    - [ ] litellm.taylor.lan (or litellm-gateway.taylor.lan) → litellm service
    - [ ] search.taylor.lan → searxng service
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

- [x] Decide consolidated host IP: `192.168.50.50`.
- [x] Decide Ollama host IP: `192.168.50.51`.
- [x] Confirm DNS updates will be user-managed during rollout.

### Research Item 6: Portainer Scope & Governance

**Goal**: Determine whether Portainer should be added to the consolidated Docker Compose host and define safe operational boundaries.

- [x] Evaluate Portainer fit for consolidated host visibility and day-2 operations.
- [x] Define governance model:
  - [x] Keep Ansible + Compose files as source of truth.
  - [x] Restrict Portainer use to observability and controlled actions.
  - [x] Avoid unmanaged drift from ad hoc UI changes.
- [x] Decide endpoint model:
  - [x] Local Docker endpoint on `192.168.50.50`.
  - [ ] Optional remote Docker endpoints (future).
  - [x] Optional K3s endpoint (future, read-only first).
- [ ] Define baseline security controls:
  - [ ] SSO/Auth strategy (if any), admin user policy, backup of Portainer data volume.
  - [ ] Traefik route + TLS policy.

### Research Item 7: Prometheus + Grafana Placement (Compose vs K3s)

**Goal**: Decide primary observability platform placement for current and near-term architecture.

- [x] Compare deployment options:
  - [x] Option A: Docker Compose on `192.168.50.50`.
  - [x] Option B: K3s-native stack in cluster.
  - [x] Option C: Hybrid (central Grafana + mixed Prometheus targets).
- [ ] Evaluate by criterion:
  - [ ] Operational complexity for bootstrap/recovery from scratch.
  - [ ] Coverage for VM + Docker + K3s metrics.
  - [ ] Persistence/backup model simplicity.
  - [ ] Resource impact and failure domains.
- [x] Produce recommendation with phased rollout:
  - [x] Phase 1 baseline deployment choice: central Grafana + Compose-host Prometheus.
  - [x] Phase 2 expansion path when K3s workloads grow: per-cluster Prometheus, all as Grafana datasources.

### Research Item 8: Consul Requirement Decision

**Goal**: Determine whether Consul adds practical value beyond current DNS + Traefik + Ansible inventory model.

- [x] Document concrete use cases that would justify Consul introduction.
- [x] Primary near-term use case captured: post-K3s service mesh and service-discovery experimentation.
- [ ] Compare alternatives:
  - [x] DNS records + Traefik labels + static inventory (current direction).
  - [x] Consul service discovery/health checks.
  - [x] K3s-native service discovery for in-cluster workloads.
- [ ] Define adoption threshold:
  - [x] Conditions under which Consul is introduced.
  - [x] Conditions under which Consul is explicitly deferred.
- [x] Produce recommendation: adopt now, pilot later, or defer.
- [x] Decision: defer now; pilot later after K3s baseline is stable.

- [ ] Update inventory.ini with new consolidated host group:
  - [ ] `[docker_compose_consolidated]` or similar group name
  - [ ] Remove/reassign old groups (registry, openwebui, lldap)
  - [ ] Map re-purposed/decommissioned IPs (old registry/openwebui/lldap placements)

- [ ] Update DNS records (Technitium on 192.168.50.53):
  - [ ] registry.taylor.lan → consolidated IP
  - [ ] ldap.taylor.lan → consolidated IP
  - [ ] chat.taylor.lan → consolidated IP
  - [ ] litellm.taylor.lan → consolidated IP
  - [ ] search.taylor.lan → consolidated IP
  - [ ] anythingllm.taylor.lan → consolidated IP
  - [ ] n8n.taylor.lan → consolidated IP
  - [ ] qdrant.taylor.lan → consolidated IP
  - [ ] Any new services → consolidated IP

- [ ] Plan decommissioning:
  - [ ] Confirm VM rebuild/reinitialize completion for new roles on `192.168.50.50` and `192.168.50.51`.
  - [ ] Decide retirement/reassignment timing for prior OpenWebUI host `192.168.50.91`.
  - [ ] Backup/snapshot strategy before decommissioning
