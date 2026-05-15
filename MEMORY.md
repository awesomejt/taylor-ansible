# MEMORY

- 2026-05-14: Added `vault.yaml` + `roles/vault` for HashiCorp Vault (192.168.50.13 / vault.taylor.lan); native binary (Raft storage), Nginx proxy on :80/:443 → :8200; UI enabled. Vault requires manual `vault operator init` + `vault operator unseal` after first deploy. TLS via step-ca (certs.taylor.lan) is supported; see role README for cert issuance steps.

- 2026-05-10: LiteLLM dashboard login/auth endpoints require a configured database; running with only LITELLM_MASTER_KEY causes `Not connected to DB!` errors for UI auth/update flows.
- 2026-05-10: AI stack now includes a Postgres service for LiteLLM with `DATABASE_URL` wired via vault-backed `vault_openwebui_postgres_password`.
- 2026-05-10: Hermes profiles were moved to LiteLLM (`hermes_litellm_base_url`) with model aliases (`use-chat`, `use-coding`, `use-thinking`) and web search configured to SearXNG via `SEARXNG_URL` + `web.search_backend=searxng`.
- 2026-05-14: Added `registry.yaml` + `roles/registry` for Docker Distribution `registry:3` behind an Nginx reverse proxy; role includes TLS-ready toggle variables and uses Docker Compose managed by systemd.
- 2026-05-14: Registry proxy routing now serves UI at `/` and Docker Registry API at `/v2/`; HTTPS server block is configured to use the same split routing when TLS is enabled.
