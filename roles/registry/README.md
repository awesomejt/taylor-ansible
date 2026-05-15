# registry role

Purpose:

- Deploy Docker Distribution `registry:3` behind Nginx.
- Serve the registry API on `/v2/`.
- Serve the Docker Registry UI on `/`.
- Keep the stack TLS-ready so HTTPS can be enabled later without changing the basic layout.

Typical usage:

- Run the playbook from the repo root:

```bash
ansible-playbook -i inventory.ini registry.yaml
```

- Expected inventory group:

```ini
[registry]
192.168.50.50
```

What the playbook does:

- Applies common host updates and Docker prerequisites through the shared roles.
- Creates the registry data, config, Nginx, and cert directories.
- Renders the registry configuration, Nginx reverse proxy config, and compose file.
- Deploys the systemd unit that manages the compose stack.
- Starts and validates the registry endpoint on `/v2/`.

Role layout:

- `roles/registry/tasks/main.yaml` orchestrates the deployment.
- `roles/registry/defaults/main.yaml` holds image names, ports, paths, and proxy settings.
- `roles/registry/templates/compose.yaml.j2` defines the registry, Nginx, and UI containers.
- `roles/registry/templates/nginx.conf.j2` routes `/` to the UI and `/v2/` to the registry API.
- `roles/registry/templates/registry-config.yml.j2` configures the registry backend.

Default endpoints:

- Registry UI: `http://registry.taylor.lan/`
- Registry API: `http://registry.taylor.lan/v2/`

HTTP client setup:

- The current deployment serves the registry over plain HTTP.
- Docker clients must treat the registry as an insecure registry until TLS is enabled.
- Add the registry host to the Docker daemon config on each client:

```json
{
	"insecure-registries": [
		"registry.taylor.lan"
	]
}
```

- If you prefer to use the IP address instead of DNS, add that exact host instead.
- Restart Docker after changing the daemon config:

```bash
sudo systemctl restart docker
```

- Confirm Docker picked up the setting:

```bash
docker info | grep -A5 "Insecure Registries"
```

Using the registry from Docker:

```bash
docker login registry.taylor.lan
docker pull alpine:latest
docker tag alpine:latest registry.taylor.lan/alpine:latest
docker push registry.taylor.lan/alpine:latest
```

TLS-ready notes:

- The Nginx template already supports HTTPS routing for both `/` and `/v2/`.
- To enable TLS later, set `registry_proxy_tls_enabled: true` and provide the certificate and key files in the expected certs directory on the target host.
- Once TLS is enabled and trusted by your client, you should remove the insecure registry entry from Docker daemon config.

Operational notes:

- The UI is intended to be the human-facing entry point.
- The Docker client should always interact with the API through `/v2/`.
- If you are testing changes, verify both:

```bash
curl -i http://registry.taylor.lan/
curl -i http://registry.taylor.lan/v2/
```

- If you later enable TLS, repeat those checks with `https://` and a client that trusts the certificate chain.