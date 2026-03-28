# nexus role

Purpose:

- Install and run Sonatype Nexus Repository OSS.
- Optionally place Nginx in front of Nexus on port 80 or 443.
- Optionally expose a Docker hosted repository through the reverse proxy.
- Optionally manage backups and Let's Encrypt certificates.

Typical usage:

- Run the playbook from the repo root:

```bash
ansible-playbook -i inventory.ini nexus.yaml --ask-vault-pass
```

- Inventory group expected:

```ini
[nexus]
192.168.50.12
```

What the playbook does:

- Installs Nexus Repository OSS.
- Configures Nexus to run as the `nexus` system user.
- Starts Nexus and waits for the REST API to come up.
- Optionally installs Nginx and reverse proxies Nexus.
- Optionally creates a hosted Docker repository in Nexus through the REST API.

Expected variables:

- These are defined by role defaults and may be overridden as needed:

- `nexus_version`
- `nexus_install_dir`
- `nexus_data_dir`
- `nexus_java_package`
- `nexus_java_opts`
- `nexus_limit_nofile`
- `nexus_backup_enabled`
- `nexus_backup_dir`
- `nexus_backup_retention_days`
- `nexus_backup_cron`

- Reverse proxy settings:

- `nexus_nginx_enable`
- `nexus_nginx_server_name`
- `nexus_nginx_use_ssl`
- `nexus_nginx_ssl_cert`
- `nexus_nginx_ssl_key`
- `nexus_nginx_client_max_body_size`
- `nexus_nginx_letsencrypt_enable`
- `nexus_nginx_letsencrypt_email`
- `nexus_nginx_letsencrypt_staging`

- Docker registry settings:

- `nexus_docker_registry_enable`
- `nexus_docker_registry_host`
- `nexus_docker_repository_name`
- `nexus_docker_blob_store_name`
- `nexus_docker_force_basic_auth`
- `nexus_docker_v1_enabled`
- `nexus_docker_strict_content_type_validation`
- `nexus_docker_write_policy`

Expected secrets and common vars:

- The playbook currently loads:

- `vars/common/vars.yaml`
- `vars/common/secrets.yaml`

- The most important values are:

- `nexus_username`
- `nexus_password`
- `vault_nexus_password`

- In the current repo, common vars already set:

- `nexus_nginx_enable: true`
- `nexus_nginx_server_name: "nexus.taylor.lan"`
- `nexus_docker_registry_enable: true`
- `nexus_docker_registry_host: "docker.nexus.taylor.lan"`
- `nexus_docker_repository_name: "docker-hosted"`

Basic access:

- Direct Nexus listens on port `8081`.
- With Nginx enabled, the intended UI endpoint is:

```text
http://nexus.taylor.lan
```

- If TLS is enabled later, the intended endpoint becomes:

```text
https://nexus.taylor.lan
```

Docker registry usage:

- This role can create a hosted Docker repository in Nexus named by `nexus_docker_repository_name`.
- The preferred Docker endpoint is the dedicated Docker hostname:

```text
docker.nexus.taylor.lan
```

- Example workflow:

```bash
docker login docker.nexus.taylor.lan
docker pull ubuntu:latest
docker tag ubuntu:latest docker.nexus.taylor.lan/ubuntu:latest
docker push docker.nexus.taylor.lan/ubuntu:latest
```

- The reverse proxy also supports Docker v2-style routing on the main Nexus hostname, but the dedicated Docker hostname is the cleaner option.

HTTP vs HTTPS for Docker:

- Docker clients strongly prefer HTTPS for registries.
- If `nexus_nginx_use_ssl` is `false`, Docker will treat the registry as insecure unless you configure the client host to trust plain HTTP for that registry.
- For normal long-term usage, enable TLS for both:

- `nexus.taylor.lan`
- `docker.nexus.taylor.lan`

- You can do that by either:

- setting `nexus_nginx_use_ssl: true` and providing cert/key paths, or
- enabling `nexus_nginx_letsencrypt_enable: true` with a valid public DNS name and email, or
- later integrating certificates issued by your internal CA.

Allowing the insecure registry on a Docker client:

- If you are testing with plain HTTP, configure Docker Engine on the client machine to allow the Nexus Docker hostname as an insecure registry.

- Example `/etc/docker/daemon.json`:

```json
{
	"insecure-registries": [
		"docker.nexus.taylor.lan"
	]
}
```

- If you are using a non-default port, include the port in the registry entry:

```json
{
	"insecure-registries": [
		"docker.nexus.taylor.lan:80"
	]
}
```

- Restart Docker after editing the daemon configuration:

```bash
sudo systemctl restart docker
```

- You can verify the setting is active with:

```bash
docker info | grep -A5 "Insecure Registries"
```

- After that, log in and push again:

```bash
docker login docker.nexus.taylor.lan
docker tag ubuntu:latest docker.nexus.taylor.lan/ubuntu:latest
docker push docker.nexus.taylor.lan/ubuntu:latest
```

Operational notes:

- Nexus startup is not instant; the role waits for the local REST status endpoint before continuing.
- Docker repository creation uses the Nexus API and requires valid admin credentials.
- The Docker repository created by this role is hosted, not proxy or group.
- If you need a Docker proxy or group repository later, add that separately rather than overloading the hosted repo configuration.