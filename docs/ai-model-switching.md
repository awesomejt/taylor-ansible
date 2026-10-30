# LiteLLM model names and switching (homelab router)

The homelab LiteLLM (`litellm.yaml`, `roles/litellm`) runs on the docker VM 192.168.50.50:4000 (`https://litellm.taylor.lan`).
Hermes, Open WebUI and AnythingLLM use it. Switching a model on a machine is covered in
`~/projects/ai/local/servers/SWITCHING-MODELS.md`, which is the source of truth for the ai-server, minisys, Mac Mini and workstation.
This page covers the names LiteLLM exposes and how to change them.

## Model names

| Kind | Names | Notes |
|---|---|---|
| General aliases | `use-chat`, `use-thinking`, `use-coding` | Mac Mini first (always loaded, never swaps the ai-server), then ai-server, minisys, Ollama |
| Role tiers | `main` (ai-server 27B coder), `manager` (ai-server 35B), `flash` (ai-server Flash-Next, swaps both cards), `orch` (minisys), `research`, `light` (Mac Mini 35B), `review` (Mac Mini Qwen3-Coder), `worker` (workstation gpt-oss-20b), `bk-minisys`, `bk-macmini` | Same roles as the MacBook router's time-track `tt-*` names; fallback chains as there, minus the MacBook itself |
| ai-server catalog | `aiserver-qwen38-27b`, `aiserver-qwen36-35b`, `aiserver-flash-next`, `aiserver-flash-strata`, `aiserver-swift-27b`, `aiserver-gemma4-31b`, `aiserver-gemma4-26b`, `aiserver-glm47-flash`, `aiserver-muse-30b` | **Asking for one loads it on the ai-server** (llama-swap). No fallbacks |
| Other machines | `minisys-lane`, `macmini-qwen36-35b`, `macmini-qwen38-27b`, `macmini-qwen3-coder-30b`, `macmini-gemma4-26b`, `macmini-gpt-oss-20b`, `workstation-gpt-oss-20b` | No fallbacks |
| Ollama | `ollama-chat`, `ollama-coding`, `ollama-thinking`, `ollama-hermes3`, `ollama-gemma4`, `local-ollama` | CPU, always on |

Removed on 2026-10-29: `omlx-primary-*`, `omlx-secondary-*`, `ws2-lmstudio-*` and `homelab-*`. They pointed at model ids and
hosts that no longer exist (ws2 is now the ai-server; the MacBook oMLX is a laptop and is off), so every request through them
was ending up on Ollama.

## Using a specific model

- **Open WebUI**: pick it from the model list. Choosing an `aiserver-*` model makes the first reply wait while the ai-server
  loads it (10-80 s). The ai-server keeps it loaded afterwards, so run `ai-model production` on the ai-server when you are finished.
- **Hermes**: set `model:` for the profile in `vars/common/vars.yaml` (`hermes_profiles`), then apply `hermes.yaml`. Keep
  Hermes on `use-*` or `macmini-*` names unless you want Hermes traffic to swap the ai-server: its 45 s timeout is shorter
  than some loads.
- **Any client**: send the name as `model` to `https://litellm.taylor.lan/v1` with the master key.

## Changing the routing

Everything is data in `roles/litellm/defaults/main.yaml`:

- `litellm_models`: one entry per name. Fields are `name`, `model` (the backend id), `api_base`, plus optional `api_key`,
  `provider` (default `openai`), `max_input_tokens`, `timeout` and `stream_timeout`.
- `litellm_fallbacks`: `{model, to: [...]}`. Fallbacks are **not transitive**, so list the whole chain.
- Backend URLs are set once in `litellm_aiserver_base_url`, `litellm_minisys_base_url`, `litellm_macmini_base_url`,
  `litellm_workstation_base_url` and `litellm_ollama_base_url`.

To point the general aliases at the ai-server instead (faster, but it can interrupt review windows), change the `use-*`
entries to `model: tt-manager` / `tt-coder` with `api_base: "{{ litellm_aiserver_base_url }}"`, and put `bk-macmini` first
in their fallbacks.

Apply (from the Mac, then on the Ansible host):

```bash
./sync-to-ansible.sh
ssh 192.168.50.11
cd ~/ansible && ansible-playbook -i inventory.ini litellm.yaml --vault-password-file ~/avpass
ansible-playbook -i inventory.ini ai-validation.yaml --vault-password-file ~/avpass   # refresh the alias check list
```

Check:

```bash
curl -s https://litellm.taylor.lan/v1/models -H "Authorization: Bearer <master key>" | jq -r '.data[].id'
```
