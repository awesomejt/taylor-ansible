# Ollama Role

Deploys Ollama (open-source LLM inference server) as a Docker Compose service on a dedicated host.

## Purpose

Provides CPU-only (or GPU-accelerated if available) LLM inference endpoint for:
- OpenWebUI stack (LiteLLM models)
- AnythingLLM embedding models
- Fallback inference provider when specialized accelerators (oMLX) are unavailable

## Configuration

- **ollama_port**: Service port (default: 11434)
- **ollama_data_dir**: Model storage location
- **ollama_models_to_pull**: List of models to auto-pull after deployment (optional)
- **ollama_nginx_enable**: Enable Nginx reverse proxy for easy browser access (default: false)
- **ollama_nginx_server_name**: DNS hostname served by Nginx (default: ollama.taylor.lan)

## Typical Usage

```yaml
# defaults/main.yaml override
ollama_models_to_pull:
  - llama3.2:latest
  - qwen2.5-coder:latest
  - ministral-3:latest
```

## Service Endpoint

Once deployed, Ollama listens on `http://<host>:11434` and provides:
- `GET /api/tags` - List available models
- `POST /api/generate` - Generate text from a model
- `POST /api/pull` - Pull a new model
- `POST /api/embeddings` - Generate embeddings

When `ollama_nginx_enable` is true, Nginx also exposes Ollama on `http://<ollama_nginx_server_name>` (default port 80) while keeping the direct API port available for LiteLLM and other clients.

## Notes

- Models are stored in persistent `{{ ollama_data_dir }}` to survive container restarts.
- First deployment may take time if pulling large models.
- GPU support is automatic if NVIDIA drivers and `nvidia-docker` are available.
