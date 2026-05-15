# MEMORY

- 2026-05-15: Technitium DNS Server is currently pinned to version 15.2 in `roles/technitium-dns/defaults/main.yaml`; upstream site also reports 15.2 as the latest version. The upgrade flow now creates backups under `/var/backups/technitium` before running the installer.

- 2026-05-15: Added `lldap.yaml` + `roles/lldap` for LLDAP on 192.168.50.51 (`ldap.taylor.lan`) with Docker Compose and Nginx reverse proxy for web UI; LDAP remains direct on TCP 3890. Backend persistence is PostgreSQL on `postgres_prod` (192.168.50.15), provisioned by the first play in `lldap.yaml`.
- 2026-05-15: Applied `lldap.yaml` successfully from Ansible host; DB/user were created on `postgres_prod` and LLDAP came up on 192.168.50.51. From 192.168.50.11, direct IP checks passed (`http://192.168.50.51` and `:3890`), but `ldap.taylor.lan` did not resolve at verification time.
- 2026-05-15: DNS for `ldap.taylor.lan` was later fixed; from 192.168.50.11, `getent hosts ldap.taylor.lan` resolves to 192.168.50.51 and both HTTP (`200`) and LDAP TCP (`:3890`) checks pass by hostname.

- 2026-05-14: Added `vault.yaml` + `roles/vault` for HashiCorp Vault (192.168.50.13 / vault.taylor.lan); native binary (Raft storage), Nginx proxy on :80/:443 → :8200; UI enabled. Vault requires manual `vault operator init` + `vault operator unseal` after first deploy. TLS via step-ca (certs.taylor.lan) is supported; see role README for cert issuance steps.

- 2026-05-10: LiteLLM dashboard login/auth endpoints require a configured database; running with only LITELLM_MASTER_KEY causes `Not connected to DB!` errors for UI auth/update flows.
- 2026-05-10: AI stack now includes a Postgres service for LiteLLM with `DATABASE_URL` wired via vault-backed `vault_openwebui_postgres_password`.
- 2026-05-10: Hermes profiles were moved to LiteLLM (`hermes_litellm_base_url`) with model aliases (`use-chat`, `use-coding`, `use-thinking`) and web search configured to SearXNG via `SEARXNG_URL` + `web.search_backend=searxng`.
- 2026-05-14: Added `registry.yaml` + `roles/registry` for Docker Distribution `registry:3` behind an Nginx reverse proxy; role includes TLS-ready toggle variables and uses Docker Compose managed by systemd.
- 2026-05-14: Registry proxy routing now serves UI at `/` and Docker Registry API at `/v2/`; HTTPS server block is configured to use the same split routing when TLS is enabled.

## Docker Compose Consolidation Planning (2026-05-15)

### Analysis Summary
Reviewed all 16 playbooks and 14+ roles to assess consolidation opportunities:

**Current Docker Compose Services (3 hosts, 5 compose stacks):**
- OpenWebUI stack (192.168.50.91): open-webui, litellm, ollama, searxng, anythingllm, n8n, qdrant, postgres
- LLDAP (192.168.50.51): lldap + nginx
- Registry (192.168.50.50): registry:3 + nginx
- Hermes (192.168.50.92): Python-based AI agent orchestrator + services
- Nexus (192.168.50.12): Artifact repository (standalone systemd)

**Dedicated VMs Required (System Critical):**
- DNS (192.168.50.53, Technitium): Port 53 binding, system resolver, too risky to containerize
- Step CA (192.168.50.9): PKI infrastructure, certificate generation, best on dedicated VM
- PostgreSQL (192.168.50.15, 16, 28): Three instances per environment (prod/stage/dev); data persistence, performance, LLDAP/OpenWebUI depend on these
- Vault (192.168.50.13): Secrets management, critical path for all playbooks, recommend staying dedicated
- K3s Clusters (prod/stage/dev): Resource intensive, already distributed, each environment justified

### Consolidation Candidates (Moveable to Single Docker Compose VM)
1. **LLDAP** (192.168.50.51) → Consolidate
   - Lightweight, stable container
   - Current deps: postgres_prod (keep external, just change DB host in secrets)
   - Web UI + LDAP protocol, no port conflicts
   - Can move to shared traefik_proxy network

2. **Registry** (192.168.50.50) → Consolidate
   - Lightweight container, read-heavy, low CPU/memory
   - No critical deps, just needs Docker
   - Nginx reverse proxy already pattern-matched in consolidation host

3. **OpenWebUI Stack** (192.168.50.91) → Consolidate (with caveats)
   - Currently 8 services in one compose: open-webui, litellm, ollama, searxng, anythingllm, n8n, qdrant, postgres
   - **Problem**: postgres service in this stack should move to dedicated postgres_prod VM
   - **Recommendation**: Deploy postgres-less version on consolidated host, change DATABASE_URL to external postgres_prod
   - Keep ollama on this host (resource intensive, GPU-compatible, benefits from local scheduling)
   - Consolidate: open-webui, litellm, searxng, anythingllm, n8n, qdrant to single Docker Compose VM

4. **Nexus** (192.168.50.12) → Keep on dedicated VM or move
   - Current: systemd + Java binary, ~1GB footprint
   - Could Docker-compose on consolidated host if storage isolation not critical
   - **Recommendation**: Move to K8s for better resource management and HA

5. **Hermes** (192.168.50.92) → Keep dedicated
   - Python 3.14 + Node.js 24 runtime, system user orchestration
   - Requires Discord token management, Git identity binding, uv package manager
   - Profile system implies scalability (multiple profiles/bots possible)
   - **Recommendation**: Keep dedicated for operational simplicity and future scaling

### K8s Migration Candidates
1. **Nexus Repository**: Static artifact repository, good fit for K8s StatefulSet
2. **Registry**: Could run in K8s with persistent volume, though light enough for Docker Compose
3. **AnythingLLM, N8N, Qdrant**: Document/workflow/vector processing, good K8s candidates
4. **OpenWebUI**: Web UI + LLM interface, natural K8s workload
5. **LiteLLM + SearXNG**: Gateway services, excellent K8s candidates

### Services Requiring External Dependencies
- **LLDAP**: postgres_prod (192.168.50.15) — change DB host via vault secret
- **OpenWebUI components**: postgres_prod (192.168.50.15) for LiteLLM dashboard DB — move service to dedicated postgres or use external
- **Registry**: None (self-contained)
- **AnythingLLM/N8N**: May require persistent volumes/datastores

### Proposed Consolidated Docker Compose VM Target
**New single Docker Compose host** (TBD IP, suggest 192.168.50.75 or consolidate into 192.168.50.91):
- Stack 1: LLDAP + Nginx (replaces 192.168.50.51)
- Stack 2: Registry + Nginx (replaces 192.168.50.50)
- Stack 3: OpenWebUI ecosystem (open-webui, litellm, searxng, anythingllm, n8n, qdrant, ollama) (consolidates 192.168.50.91)
- Shared: traefik_proxy bridge network across all stacks for Traefik virtual host routing

### Networking Architecture (Proposed)
- **Each Docker Compose stack**: Isolated bridge network (default or named)
- **Shared ingress network**: `traefik_proxy` bridge connected to all stacks
- **Traefik placement option A**: Run on consolidated Docker Compose host, route external :80/:443 to stack services
- **Traefik placement option B**: Run in K3s, use external ingress to reach Docker Compose stacks (requires extra routing logic)
- **Recommendation**: Place Traefik on consolidated Docker Compose host, expose ports :80/:443, label services for auto-discovery

### Deployment Order (No Circular Deps)
1. **Baseline**: updates + common on all hosts
2. **Core Infrastructure** (sequential, no parallelization):
   - DNS (192.168.50.53) → required for all DNS-based bootstraps
   - Step CA (192.168.50.9) → TLS for all services
   - PostgreSQL prod/stage/dev (192.168.50.15, 16, 28) → foundation for LLDAP, OpenWebUI, others
   - Vault (192.168.50.13) → secrets provider for all subsequent plays
3. **Container Runtime**:
   - Docker (on Docker hosts) → foundation for compose stacks
4. **Consolidated Docker Compose VM**:
   - Registry (192.168.50.50 → consolidated host)
   - LLDAP (192.168.50.51 → consolidated host)
   - OpenWebUI stack (192.168.50.91 → consolidated host)
5. **Dedicated Services**:
   - Nexus (192.168.50.12) → before K3s bootstrap if used as artifact source
   - OpenClaw (192.168.50.90) → any time after Docker + Python 3.13+ (no deps)
6. **Kubernetes** (one environment at a time):
   - K3s cluster bootstrap (k3s-cluster.yaml per env)
   - K3s bootstrap (Argo CD + SOPS, first server only)
   - K3s workload deployment via GitOps
7. **Hermes** (192.168.50.92):
   - Last, after LiteLLM endpoint stable on consolidated host
   - Requires profiles config + Discord tokens via vault

### Secrets Refactoring
- LLDAP secrets: change `db_host` from `lldap_db_host: postgres_prod` to external host
- OpenWebUI/LiteLLM: separate DB from compose, use `DATABASE_URL=postgresql://user:pass@postgres_prod:5432/litellm_db`
- New Traefik secrets: Basic auth, certificates (via step-ca), TLS keys
- Existing vault structure (vars/common/secrets.yaml, vars/prod/secrets.yaml, etc.) unchanged

### Advantages of Consolidation
1. **Reduced VM count**: 3 hosts (50, 51, 91) → 1 consolidated host
2. **Simplified networking**: All services on one network, easier Traefik integration
3. **Resource efficiency**: Less total compute, easier to migrate to larger single host if needed
4. **Operational simplicity**: One Docker Compose file per environment (or modular stack)
5. **Cost savings**: Fewer VMs = fewer IP allocations, less memory overhead from multiple systemd instances

### Risks & Mitigations
- **Single point of failure**: Consolidated host down = 3 services down (LLDAP, Registry, OpenWebUI). Mitigation: backup-capable VM, snapshot before consolidation, quick failover to K8s for stateless services.
- **Resource contention**: CPU/memory bottleneck if many requests to OpenWebUI + other services. Mitigation: right-size VM (suggest 16GB RAM, 8+ CPU cores), monitor utilization, split into 2 hosts if needed.
- **Network conflicts**: Port collision on consolidated host. Mitigation: Use Traefik on :80/:443, internal service ports on non-standard ranges (8000+).
- **Dependency ordering**: LLDAP/OpenWebUI need external postgres. Mitigation: Document DB connection strings in secrets, validate in playbook before deploy.

### User Feedback & Refinements (2026-05-15)

**Confirmed Decisions**:
- Core/critical services stay dedicated (DNS, Vault, Step CA, PostgreSQL, K3s)
- Ollama moves to dedicated VM (CPU-only fallback provider, not primary, benefits from isolation)
- Networking model approved: isolated stack networks + shared traefik_proxy
- PostgreSQL consolidation confirmed: all services use dedicated postgres_prod/stage/dev VMs

**Strategy Refinements**:

1. **AI Compose Stack Decomposition**
   - Current monolithic approach: all services in one compose file
   - Desired approach: break into separate services, each with own Traefik virtual host
   - Rationale: Cleaner URLs (e.g., `openwebui.taylor.lan`, `litellm-gateway.taylor.lan`, `anythingllm.taylor.lan`)
   - Each service gets its own reverse proxy entry via Traefik labels
   - Still consolidates to single VM, but services are logically separate for clarity
   - Example structure:
     - compose-openwebui.yaml → open-webui service only
     - compose-litellm.yaml → litellm gateway service
     - compose-searxng.yaml → searxng search proxy
     - compose-anythingllm.yaml → document intelligence
     - compose-n8n.yaml → workflow automation
     - compose-qdrant.yaml → vector database
     - All connect to traefik_proxy network

2. **Build Asset & Library/Dependency Management** (OPEN FOR RESEARCH)
   - Current state: Simple Docker registry (192.168.50.50) + separate Nexus (192.168.50.12)
   - Trade-offs to evaluate:
     - **Simple registry (current)**: Lightweight, minimal resources, no UI (added external), no library mgmt
     - **Harbor**: Comprehensive, includes UI/RBAC/scanning, moderate resource overhead, proven in production
     - **Nexus**: All-in-one (Docker, Maven, npm, etc.), higher resource cost (~2GB+), learning curve, possibly overkill
   - Decision factors: scope of library mgmt needed, resource budget, operational complexity
   - Option to keep registry separate from libraries if they serve different purposes
   - **TODO**: Research and document pros/cons, resource requirements, migration path

3. **Nexus Placement & HA** (OPEN FOR DECISION)
   - User prefers no HA (single instance sufficient)
   - Persistence is simpler on VM with Docker Compose than in K8s StatefulSet
   - Options:
     - Option A: Keep dedicated VM (192.168.50.12), Docker Compose instead of systemd binary
     - Option B: Fold into consolidated Docker Compose VM (192.168.50.75 or 192.168.50.91)
   - Decision factors: resource availability, artifact replication needs, operational preference
   - **TODO**: Document decision criteria and recommendation

4. **Common Homelab Services** (OPEN FOR RESEARCH)
   - User seeks recommendations for additional services suitable for consolidated Docker Compose host
   - Categories to explore:
     - Monitoring/logging: Prometheus, Grafana, Loki, ELK stack (or lightweight alternatives)
     - Reverse proxy/ingress: Caddy as alternative to Traefik, nginx-proxy, Authelia for SSO
     - Media management: Plex, Jellyfin, Radarr, Sonarr, Lidarr
     - Smart home: Home Assistant, MQTT broker (Mosquitto)
     - VPN/networking: Wireguard, Tailscale
     - Data storage/sync: Syncthing, Nextcloud
     - Development: GitLab/Gitea, Forgejo
     - CI/CD: Woodpecker CI, Drone CI
     - Database GUIs: pgAdmin, DBeaver, adminer
   - Focus on: low resource overhead, stateless or simple persistence, good Traefik integration
   - **TODO**: Research and recommend top candidates with resource profiles

### Revised Consolidation Strategy

**Consolidated Docker Compose Host** (single VM, 192.168.50.75 or reuse 192.168.50.91):
- Registry stack (registry:3 + nginx)
- LLDAP stack (lldap + nginx) with external postgres_prod
- OpenWebUI: decomposed into separate services (see above)
- Optional: Nexus (if moving from dedicated VM)
- Optional: Additional homelab services (Prometheus, Grafana, pgAdmin, etc.)
- Shared: traefik_proxy bridge network + Traefik ingress on :80/:443

**Separate/Dedicated Hosts**:
- Core infrastructure: DNS, Step CA, Vault, PostgreSQL (prod/stage/dev), K3s clusters
- Ollama: New dedicated VM for LLM inference (CPU fallback, isolation)
- Hermes: Remains dedicated (complex runtime, profiles, Discord tokens)
- Optional: Nexus on separate VM (if not consolidated)
- Optional: Other high-resource services (Plex, Jellyfin, heavy monitoring)

**Networking**:
- Each Docker Compose service has isolated internal network (or shared internal network within service)
- All services connect to traefik_proxy bridge for external routing
- Traefik on consolidated host handles :80/:443 ingress + virtual host routing
- Services exposed via Traefik labels:
  - `traefik.enable=true`
  - `traefik.http.routers.service.rule=Host(\`service.taylor.lan\`)`
  - `traefik.http.services.service.loadbalancer.server.port=SERVICE_PORT`
  - Optional: TLS, auth, rate limiting per service
