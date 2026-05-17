# harbor role

Purpose:

- Deploy Harbor on the Docker Compose host using the upstream Harbor installer artifacts.
- Integrate Harbor with external PostgreSQL on `postgres_prod`.
- Route Harbor through Traefik by attaching Harbor's proxy service to the shared `traefik_proxy` network.
- Attempt LDAP auth wiring against LLDAP through Harbor's configuration API.

Typical usage:

```bash
ansible-playbook -i inventory.ini harbor.yaml --vault-password-file ~/avpass
```

What the playbook does:

- Provisions Harbor database/user on `postgres_prod`.
- Downloads and extracts Harbor online installer assets under `/opt/harbor/harbor`.
- Renders `harbor.yml` with external database settings and admin bootstrap password.
- Renders a compose override for Traefik labels/network.
- Runs `prepare` and manages Harbor containers via `harbor.service`.
- Waits for Harbor UI/API readiness and attempts LDAP configuration.

Notes:

- Harbor keeps a local `admin` account even when LDAP auth mode is enabled.
- `harbor_admin_password` is only used during first install/bootstrap.
- If the LDAP API call is rejected by the installed Harbor version, configure LDAP from Harbor UI under Authentication.
