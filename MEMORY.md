# MEMORY

- 2026-05-10: LiteLLM dashboard login/auth endpoints require a configured database; running with only LITELLM_MASTER_KEY causes `Not connected to DB!` errors for UI auth/update flows.
- 2026-05-10: AI stack now includes a Postgres service for LiteLLM with `DATABASE_URL` wired via vault-backed `vault_openwebui_postgres_password`.
- 2026-05-10: Hermes profiles were moved to LiteLLM (`hermes_litellm_base_url`) with model aliases (`use-chat`, `use-coding`, `use-thinking`) and web search configured to SearXNG via `SEARXNG_URL` + `web.search_backend=searxng`.
